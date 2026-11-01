import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'data/taqwa_repository.dart';
import 'domain.dart';
import 'link_sync.dart';
import 'notifications.dart';

class Habit {
  const Habit({required this.id, required this.name, this.builtIn = false});
  final int id;
  final String name;
  final bool builtIn;
}

class TaqwaController extends ChangeNotifier {
  TaqwaController(
    this.repository, {
    DateTime Function()? clock,
    LinkSyncService? linkSync,
  }) : _clock = clock ?? DateTime.now,
       linkSync = linkSync ?? LinkSyncService();

  final TaqwaRepository repository;
  final DateTime Function() _clock;

  /// Sorgt dafür, dass ein einziger Scan beide Geräte verknüpft.
  final LinkSyncService linkSync;

  AppSettings? settings;
  PrayerSchedule? schedule;
  Map<Prayer, bool> prayers = {};
  Map<Prayer, bool> todayPrayers = {};
  List<Habit> habits = [];
  Map<int, HabitStatus> todayHabits = {};
  Map<String, Map<int, HabitStatus>> weekHabits = {};
  List<Partner> partners = [];
  Map<String, List<FamilyMessage>> partnerMessages = {};
  List<(int, int)> bookmarks = [];
  DateTime selectedDate = DateTime.now();
  bool ready = false;
  String? error;

  /// Leseposition im Quran. Ein eigener Notifier sorgt dafür, dass beim
  /// Scrollen nur die „Weiterlesen“-Karte aktualisiert wird und nicht die
  /// komplette App neu gebaut werden muss.
  final ValueNotifier<(int, int)?> lastReadNotifier = ValueNotifier(null);
  (int, int)? get lastRead => lastReadNotifier.value;

  /// Wird gesetzt, sobald heute von 5/5 auf Gold gewechselt wurde, damit die
  /// Erfolgs-Animation genau einmal läuft.
  bool goldCelebrationPending = false;
  bool _wasComplete = false;

  DateTime get now => _clock();
  DateTime get today {
    final current = now;
    return DateTime(current.year, current.month, current.day);
  }

  int get completedPrayers => prayers.values.where((done) => done).length;
  int get completedPrayersToday =>
      todayPrayers.values.where((done) => done).length;
  bool get allPrayersTodayDone => completedPrayersToday == Prayer.values.length;
  int get completedHabits =>
      todayHabits.values.where((s) => s == HabitStatus.done).length;
  Prayer? get nextPrayer => schedule?.nextPrayer(now);
  Duration? get timeUntilNextPrayer {
    final prayer = nextPrayer;
    if (prayer == null) return null;
    return schedule!.times[prayer]!.difference(now);
  }

  int get builtInHabitCount {
    var total = 0;
    var done = 0;
    for (final habit in habits.where((h) => h.builtIn)) {
      total++;
      if (todayHabits[habit.id] == HabitStatus.done) done++;
    }
    return total == 0 ? 0 : done;
  }

  int get builtInHabitTotal => habits.where((h) => h.builtIn).length;

  /// Schnappschuss für den eigenen QR-Code.
  ProfileSnapshot get profileSnapshot => ProfileSnapshot(
    code: settings?.profileId ?? '',
    name: settings?.name ?? '',
    prayerMask: [
      for (final prayer in Prayer.values)
        todayPrayers[prayer] == true ? '1' : '0',
    ].join(),
    habitsDone: builtInHabitCount,
    habitsTotal: builtInHabitTotal,
    streak: settings?.streak ?? 0,
    day: dayKey(today),
    reminderAt: settings?.outboxReminderAt,
    reminderText: settings?.outboxReminderText,
    syncHost: linkSync.host,
    syncPort: linkSync.port,
  );

  Future<void> initialize() async {
    try {
      settings = await repository.ensureProfile();
      selectedDate = DateTime(now.year, now.month, now.day);
      await refresh();
      _wasComplete = allPrayersTodayDone;
      ready = true;
      notifyListeners();
      await _startLinkSync();
      await applyNotificationSchedule();
    } catch (e) {
      error = 'Die lokalen App-Daten konnten nicht geladen werden: $e';
      ready = true;
      notifyListeners();
    }
  }

  Future<void> _startLinkSync() async {
    await linkSync.start(
      mySnapshot: () async => profileSnapshot,
      onPeerLinked: _handlePeerLinked,
      onMessage: _handleIncomingPing,
    );
  }

  /// Speichert einen Partner, der über das lokale WLAN dazugekommen ist.
  Future<void> _handlePeerLinked(ProfileSnapshot snapshot) async {
    if (snapshot.code.isEmpty || snapshot.code == settings?.profileId) return;
    await repository.savePartnerSnapshot(snapshot);
    partners = await repository.partners();
    notifyListeners();
  }

  /// Eine Nachricht eines gekoppelten Geräts ist eingetroffen: im Verlauf
  /// ablegen und – wenn erlaubt – sofort als Benachrichtigung zeigen.
  Future<void> _handleIncomingPing(FamilyPing ping) async {
    if (ping.fromCode.isEmpty || ping.fromCode == settings?.profileId) return;
    Partner? partner;
    for (final item in partners) {
      if (item.code == ping.fromCode) partner = item;
    }
    if (partner != null) {
      await repository.saveFamilyMessage(
        partnerCode: partner.code,
        direction: 'in',
        kind: ping.kind.name,
        text: ping.displayText,
        prayer: ping.prayer?.name,
        createdAt: now,
      );
      partners = await repository.partners();
      partnerMessages[partner.code] = await repository.familyMessages(
        partner.code,
      );
      notifyListeners();
    }
    if (settings?.familyAlerts ?? true) {
      await NotificationService.showNow(
        title: ping.notificationTitle,
        body: ping.notificationBody,
        id: 9000 + (ping.fromCode.hashCode & 0xff),
      );
    }
  }

  /// Liest die eigene IP neu ein, z. B. nach einem WLAN-Wechsel.
  Future<void> refreshLinkSync() async {
    final changed = await linkSync.refreshHost();
    if (changed) notifyListeners();
  }

  Future<void> refresh() async {
    final current = settings ?? await repository.loadSettings();
    schedule = PrayerSchedule.calculate(
      date: selectedDate,
      latitude: current.latitude,
      longitude: current.longitude,
      method: current.calculationMethod,
      hanafi: current.hanafi,
    );
    prayers = await repository.prayerStatuses(selectedDate);
    todayPrayers = dayKey(selectedDate) == dayKey(now)
        ? Map<Prayer, bool>.of(prayers)
        : await repository.prayerStatuses(now);
    habits = [
      for (final row in await repository.habits())
        Habit(
          id: row['id']! as int,
          name: row['name']! as String,
          builtIn: row['built_in'] == 1,
        ),
    ];
    todayHabits = await repository.habitStatuses(selectedDate);
    weekHabits = await repository.habitWeek(selectedDate);
    partners = await repository.partners();
    partnerMessages = {
      for (final partner in partners)
        partner.code: await repository.familyMessages(partner.code),
    };
    bookmarks = await repository.quranBookmarks();
    lastReadNotifier.value = await repository.quranProgress();
  }

  Future<PrayerAward> togglePrayer(Prayer prayer) async {
    final award = await repository.togglePrayer(selectedDate, prayer);
    settings = await repository.loadSettings();
    await refresh();
    _checkGold();
    notifyListeners();
    return award;
  }

  /// Hakt ein Gebet immer für den heutigen Tag ab – unabhängig davon,
  /// welcher Tag gerade im Kalender ausgewählt ist.
  Future<PrayerAward> togglePrayerToday(Prayer prayer) async {
    final award = await repository.togglePrayer(today, prayer);
    settings = await repository.loadSettings();
    await refresh();
    _checkGold();
    notifyListeners();
    return award;
  }

  void _checkGold() {
    final done = allPrayersTodayDone;
    if (done && !_wasComplete) {
      final day = dayKey(today);
      if (settings?.goldDay != day) {
        goldCelebrationPending = true;
        repository.updateSettings(goldDay: day);
      }
    }
    _wasComplete = done;
  }

  void clearGoldCelebration() {
    goldCelebrationPending = false;
    notifyListeners();
  }

  Future<HabitAward> setHabitStatus(int id, HabitStatus status) async {
    final award = await repository.setHabitStatus(selectedDate, id, status);
    settings = await repository.loadSettings();
    await refresh();
    notifyListeners();
    return award;
  }

  Future<void> selectDate(DateTime date) async {
    selectedDate = DateTime(date.year, date.month, date.day);
    await refresh();
    notifyListeners();
  }

  Future<void> changeMonth(int delta) async {
    final next = DateTime(selectedDate.year, selectedDate.month + delta, 1);
    await selectDate(DateTime(next.year, next.month, 1));
  }

  Future<void> addHabit(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    await repository.addHabit(clean);
    await refresh();
    notifyListeners();
  }

  Future<void> removeHabit(int id) async {
    await repository.removeHabit(id);
    await refresh();
    notifyListeners();
  }

  Future<void> updateName(String value) async {
    final clean = value.trim();
    if (clean.isEmpty) return;
    await repository.updateSettings(name: clean);
    settings = await repository.loadSettings();
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required String name,
    required String language,
  }) async {
    final clean = name.trim().isEmpty ? 'Mein Profil' : name.trim();
    final code = settings?.profileId ?? '';
    await repository.completeOnboarding(clean, code, language: language);
    settings = await repository.loadSettings();
    await refresh();
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    await repository.updateSettings(language: language);
    settings = await repository.loadSettings();
    notifyListeners();
  }

  Future<void> updateCalculation({String? method, bool? hanafi}) async {
    await repository.updateSettings(calculationMethod: method, hanafi: hanafi);
    settings = await repository.loadSettings();
    await refresh();
    notifyListeners();
    await applyNotificationSchedule();
  }

  Future<void> updateCoordinates({
    required String label,
    required double latitude,
    required double longitude,
  }) async {
    await repository.updateSettings(
      locationName: label,
      latitude: latitude,
      longitude: longitude,
    );
    settings = await repository.loadSettings();
    await refresh();
    notifyListeners();
    await applyNotificationSchedule();
  }

  Future<void> useDeviceLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw StateError('Standortdienste sind ausgeschaltet.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError(
        'Standortzugriff wurde nicht erlaubt. Du kannst Koordinaten manuell eingeben.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 12),
      ),
    );
    await updateCoordinates(
      label: 'Mein Standort',
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  // ---- Kopplung -----------------------------------------------------

  /// Verarbeitet einen gescannten QR-Code: linkt den Partner, übernimmt
  /// dessen Fortschritt und zeigt ggf. seine Erinnerung an.
  ///
  /// Danach wird der eigene Stand direkt an das gescannte Gerät geschickt.
  /// Antwortet es, ist die Kopplung sofort auf beiden Seiten aktiv.
  Future<LinkResult> linkFromScan(String raw) async {
    final snapshot = ProfileSnapshot.tryParse(raw);
    if (snapshot == null) {
      return const LinkResult(
        reason: 'Dieser QR-Code gehört nicht zu TAQWA TRACK.',
      );
    }
    if (snapshot.code == settings?.profileId) {
      throw StateError('Das ist dein eigener QR-Code.');
    }
    await repository.savePartnerSnapshot(snapshot);
    partners = await repository.partners();
    notifyListeners();
    if (snapshot.reminderAt != null) {
      await NotificationService.showNow(
        title:
            'Erinnerung von ${snapshot.name.isEmpty ? 'deinem Partner' : snapshot.name}',
        body: snapshot.reminderText ?? ProfileSnapshot.defaultReminder,
      );
    }
    final mutual = await linkSync.handshake(
      peer: snapshot,
      mine: profileSnapshot,
    );
    if (mutual) {
      partners = await repository.partners();
      notifyListeners();
    }
    return LinkResult(
      snapshot: snapshot,
      mutual: mutual,
      reason: mutual
          ? null
          : 'Die Gegenseite war nicht im selben WLAN erreichbar. '
                'Zeige ihr jetzt deinen QR-Code, damit die Kopplung auch dort ankommt.',
    );
  }

  /// Setzt einen rein lokalen Spitznamen. Der eigene Name auf dem anderen
  /// Gerät bleibt davon unberührt.
  Future<void> renamePartner(int id, String? alias) async {
    await repository.setPartnerAlias(id, alias);
    partners = await repository.partners();
    notifyListeners();
  }

  Future<void> unlinkPartner(int id) async {
    await repository.unlinkPartner(id);
    partners = await repository.partners();
    notifyListeners();
  }

  /// Legt eine Erinnerung für einen Partner an. Sie wird mit dem eigenen
  /// QR-Code übertragen und beim nächsten Scan dort angezeigt.
  Future<void> sendReminder(Partner partner) async {
    await repository.updateSettings(
      outboxReminderAt: _clock().toIso8601String(),
      outboxReminderText:
          '${settings?.name ?? 'Deine Familie'} erinnert dich ans Gebet. Möge Allah es annehmen.',
    );
    settings = await repository.loadSettings();
    await NotificationService.showNow(
      title: 'Erinnerung bereit',
      body:
          'Zeige ${partner.displayName} deinen QR-Code – die Erinnerung wird beim Scannen übertragen.',
    );
    notifyListeners();
  }

  Future<void> clearOutbox() async {
    await repository.updateSettings(clearOutbox: true);
    settings = await repository.loadSettings();
    notifyListeners();
  }

  // ---- Smarte Family-Erinnerungen -----------------------------------

  /// Fehlende Gebete, deren Zeit laut eigenem Standort schon begonnen hat.
  List<Prayer> nudgeablePrayers(Partner partner) {
    final current = settings;
    if (current == null) return const [];
    final todaySchedule = PrayerSchedule.calculate(
      date: now,
      latitude: current.latitude,
      longitude: current.longitude,
      method: current.calculationMethod,
      hanafi: current.hanafi,
    );
    return missingDuePrayers(
      prayerMask: partner.prayerMask,
      times: todaySchedule.times,
      now: now,
    );
  }

  /// Schickt eine gezielte Gebets-Erinnerung direkt an ein gekoppeltes
  /// Gerät. Gibt `false` zurück, wenn es gerade nicht erreichbar ist.
  Future<bool> sendPrayerNudge(Partner partner, Prayer prayer) async {
    final current = settings;
    if (current == null) return false;
    final ping = FamilyPing(
      fromCode: current.profileId,
      fromName: current.name,
      kind: FamilyPingKind.nudge,
      prayer: prayer,
      sentAt: now.toIso8601String(),
    );
    if (!_deliver(partner, ping)) return false;
    await _rememberMessage(partner, ping);
    return true;
  }

  /// Schickt eine kurze persönliche Nachricht an ein gekoppeltes Gerät.
  Future<bool> sendPartnerMessage(Partner partner, String text) async {
    final clean = text.trim();
    final current = settings;
    if (current == null || clean.isEmpty) return false;
    final ping = FamilyPing(
      fromCode: current.profileId,
      fromName: current.name,
      kind: FamilyPingKind.message,
      text: clean,
      sentAt: now.toIso8601String(),
    );
    if (!_deliver(partner, ping)) return false;
    await _rememberMessage(partner, ping);
    return true;
  }

  bool _deliver(Partner partner, FamilyPing ping) {
    final host = partner.syncHost?.trim() ?? '';
    final port = partner.syncPort ?? 0;
    if (host.isEmpty || port <= 0) return false;
    return linkSync.sendPing(host: host, port: port, ping: ping);
  }

  Future<void> _rememberMessage(Partner partner, FamilyPing ping) async {
    await repository.saveFamilyMessage(
      partnerCode: partner.code,
      direction: 'out',
      kind: ping.kind.name,
      text: ping.displayText,
      prayer: ping.prayer?.name,
      createdAt: now,
    );
    partnerMessages[partner.code] = await repository.familyMessages(
      partner.code,
    );
    notifyListeners();
  }

  /// Verlauf mit einem gekoppelten Gerät, neueste Nachricht zuerst.
  List<FamilyMessage> messagesFor(String code) =>
      partnerMessages[code] ?? const <FamilyMessage>[];

  // ---- Quran --------------------------------------------------------

  Future<void> saveLastRead(int surah, int ayah) async {
    if (lastRead == (surah, ayah)) return;
    await repository.saveQuranProgress(surah, ayah);
    lastReadNotifier.value = (surah, ayah);
  }

  Future<bool> toggleBookmark(int surah, int ayah) async {
    final added = await repository.toggleQuranBookmark(surah, ayah);
    bookmarks = await repository.quranBookmarks();
    notifyListeners();
    return added;
  }

  bool isBookmarked(int surah, int ayah) =>
      bookmarks.any((b) => b.$1 == surah && b.$2 == ayah);

  // ---- Tasbih -------------------------------------------------------

  Future<void> tasbihTap() async {
    final current = settings?.tasbihCount ?? 0;
    final target = settings?.tasbihTarget ?? 33;
    final next = current + 1;
    await repository.updateSettings(tasbihCount: next >= target ? 0 : next);
    settings = await repository.loadSettings();
    notifyListeners();
  }

  Future<void> setTasbihTarget(int target) async {
    await repository.updateSettings(
      tasbihTarget: target.clamp(1, 999),
      tasbihCount: 0,
    );
    settings = await repository.loadSettings();
    notifyListeners();
  }

  Future<void> resetTasbih() async {
    await repository.updateSettings(tasbihCount: 0);
    settings = await repository.loadSettings();
    notifyListeners();
  }

  // ---- Darstellung & Benachrichtigungen -----------------------------

  Future<void> setOled(bool value) async {
    await repository.updateSettings(oled: value);
    settings = await repository.loadSettings();
    notifyListeners();
  }

  /// Erscheinungsbild: `system`, `light` oder `dark`.
  Future<void> setThemeMode(String value) async {
    final normalized = switch (value) {
      'light' => 'light',
      'dark' => 'dark',
      _ => 'system',
    };
    await repository.updateSettings(themeMode: normalized);
    settings = await repository.loadSettings();
    notifyListeners();
  }

  Future<void> setAdhan({
    required bool enabled,
    required int minutesBefore,
  }) async {
    await repository.updateSettings(
      adhanEnabled: enabled,
      adhanMinutesBefore: minutesBefore.clamp(0, 30),
    );
    settings = await repository.loadSettings();
    notifyListeners();
    await applyNotificationSchedule();
  }

  /// Familien-Benachrichtigungen ein- oder ausschalten. Der Nachrichten-
  /// verlauf bleibt davon unberührt.
  Future<void> setFamilyAlerts(bool value) async {
    await repository.updateSettings(familyAlerts: value);
    settings = await repository.loadSettings();
    notifyListeners();
  }

  Future<void> applyNotificationSchedule() async {
    final current = settings;
    if (current == null) return;
    try {
      if (!current.adhanEnabled) {
        await NotificationService.cancelPrayerReminders();
        return;
      }
      await NotificationService.requestPermissions();
      final todaySchedule = PrayerSchedule.calculate(
        date: now,
        latitude: current.latitude,
        longitude: current.longitude,
        method: current.calculationMethod,
        hanafi: current.hanafi,
      );
      await NotificationService.schedulePrayerReminders(
        schedule: todaySchedule,
        minutesBefore: current.adhanMinutesBefore,
        withAdhan: true,
      );
    } catch (error) {
      debugPrint('Erinnerungen konnten nicht geplant werden: $error');
    }
  }

  Future<void> close() => repository.close();

  @override
  void dispose() {
    linkSync.stop();
    lastReadNotifier.dispose();
    super.dispose();
  }
}
