import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taqwa_track/app_controller.dart';
import 'package:taqwa_track/data/taqwa_repository.dart';
import 'package:taqwa_track/domain.dart';
import 'package:taqwa_track/hadith_screen.dart';
import 'package:taqwa_track/info_screens.dart';
import 'package:taqwa_track/main.dart';
import 'package:taqwa_track/onboarding_screen.dart';
import 'package:taqwa_track/quran_screen.dart';
import 'package:taqwa_track/screens.dart';
import 'package:taqwa_track/tasbih_screen.dart';
import 'package:taqwa_track/theme.dart';

/// In-Memory-Repository: hält alle Daten im Speicher, damit die Tests
/// ohne echte SQLite-Datei und ohne Plattform-Plugins laufen.
class _FakeRepository extends TaqwaRepository {
  _FakeRepository({bool onboarded = true}) : super(factory: databaseFactoryFfi) {
    settings = AppSettings(
      name: 'Hamza',
      xp: 0,
      streak: 0,
      locationName: 'Duisburg',
      latitude: 51.4344,
      longitude: 6.7623,
      lastCompletedDay: null,
      calculationMethod: 'muslim_world_league',
      hanafi: true,
      profileId: 'TEST01',
      onboarded: onboarded,
    );
  }

  late AppSettings settings;

  final prayerLog = <Prayer, bool>{for (final p in Prayer.values) p: false};
  final habitList = <Map<String, Object?>>[
    {'id': 1, 'name': 'Qur’an lesen', 'built_in': 1},
    {'id': 2, 'name': '100× Dhikr', 'built_in': 1},
    {'id': 3, 'name': 'Dankbarkeit', 'built_in': 1},
  ];
  final habitLog = <int, HabitStatus>{};
  final awardedHabits = <int>{};
  final linkedPartners = <Partner>[];
  final bookmarks = <(int, int)>[];
  (int, int)? progress;

  @override
  Future<AppSettings> loadSettings() async => settings;

  @override
  Future<AppSettings> ensureProfile() async => settings;

  @override
  Future<Map<Prayer, bool>> prayerStatuses(DateTime date) async => {
    ...prayerLog,
  };

  @override
  Future<PrayerAward> togglePrayer(DateTime date, Prayer prayer) async {
    prayerLog[prayer] = !prayerLog[prayer]!;
    final points = prayerLog[prayer]! ? 10 : 0;
    settings = settings.copyWith(xp: settings.xp + points);
    return PrayerAward(xpAdded: points, streakAdvanced: false);
  }

  @override
  Future<List<Map<String, Object?>>> habits() async => [
    for (final habit in habitList) {...habit},
  ];

  @override
  Future<Map<int, HabitStatus>> habitStatuses(DateTime date) async => {
    ...habitLog,
  };

  @override
  Future<Map<String, Map<int, HabitStatus>>> habitWeek(DateTime date) async =>
      {};

  @override
  Future<HabitAward> setHabitStatus(
    DateTime date,
    int id,
    HabitStatus status,
  ) async {
    habitLog[id] = status;
    final points = status == HabitStatus.done && awardedHabits.add(id) ? 5 : 0;
    settings = settings.copyWith(xp: settings.xp + points);
    return HabitAward(points);
  }

  @override
  Future<int> addHabit(String name) async {
    final id = (habitList.last['id']! as int) + 1;
    habitList.add({'id': id, 'name': name, 'built_in': 0});
    return id;
  }

  @override
  Future<void> removeHabit(int id) async =>
      habitList.removeWhere((h) => h['id'] == id);

  @override
  Future<List<Partner>> partners() async => [...linkedPartners];

  @override
  Future<Partner> savePartnerSnapshot(ProfileSnapshot snapshot) async {
    linkedPartners.removeWhere((p) => p.code == snapshot.code);
    final partner = Partner(
      id: linkedPartners.length + 1,
      code: snapshot.code,
      name: snapshot.name.isEmpty ? 'Partner' : snapshot.name,
      prayerMask: snapshot.prayerMask,
      habitsDone: snapshot.habitsDone,
      habitsTotal: snapshot.habitsTotal,
      streak: snapshot.streak,
      snapshotDay: snapshot.day,
      snapshotAt: DateTime.now().toIso8601String(),
      reminderAt: snapshot.reminderAt,
      reminderText: snapshot.reminderText,
    );
    linkedPartners.add(partner);
    return partner;
  }

  @override
  Future<void> unlinkPartner(int id) async =>
      linkedPartners.removeWhere((p) => p.id == id);

  @override
  Future<void> completeOnboarding(
    String name,
    String profileId, {
    String language = 'de',
  }) async {
    settings = settings.copyWith(
      name: name.trim().isEmpty ? 'Mein Profil' : name.trim(),
      profileId: profileId,
      language: language,
      onboarded: true,
    );
  }

  @override
  Future<List<(int, int)>> quranBookmarks() async => [...bookmarks];

  @override
  Future<bool> toggleQuranBookmark(int surah, int ayah) async {
    final index = bookmarks.indexWhere((b) => b.$1 == surah && b.$2 == ayah);
    if (index == -1) {
      bookmarks.add((surah, ayah));
      return true;
    }
    bookmarks.removeAt(index);
    return false;
  }

  @override
  Future<(int, int)?> quranProgress() async => progress;

  @override
  Future<void> saveQuranProgress(int surah, int ayah) async =>
      progress = (surah, ayah);

  @override
  Future<void> updateSettings({
    String? name,
    String? locationName,
    double? latitude,
    double? longitude,
    String? calculationMethod,
    bool? hanafi,
    String? language,
    bool? oled,
    bool? adhanEnabled,
    int? adhanMinutesBefore,
    int? tasbihCount,
    int? tasbihTarget,
    String? outboxReminderAt,
    String? outboxReminderText,
    bool clearOutbox = false,
    String? goldDay,
  }) async {
    settings = settings.copyWith(
      name: name,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      calculationMethod: calculationMethod,
      hanafi: hanafi,
      language: language,
      oled: oled,
      adhanEnabled: adhanEnabled,
      adhanMinutesBefore: adhanMinutesBefore,
      tasbihCount: tasbihCount,
      tasbihTarget: tasbihTarget,
      outboxReminderAt: outboxReminderAt,
      outboxReminderText: outboxReminderText,
      clearOutbox: clearOutbox,
      goldDay: goldDay,
    );
  }

  @override
  Future<void> close() async {}
}

void main() {
  late TaqwaController controller;
  late _FakeRepository repository;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    await initializeDateFormatting('de_DE');
  });

  setUp(() async {
    repository = _FakeRepository();
    controller = TaqwaController(
      repository,
      clock: () => DateTime(2026, 10, 30, 12),
    );
    await controller.initialize();
  });

  testWidgets('Onboarding beim ersten Start speichert Name und Sprache', (
    tester,
  ) async {
    final fresh = _FakeRepository(onboarded: false);
    final freshController = TaqwaController(
      fresh,
      clock: () => DateTime(2026, 10, 30, 12),
    );
    await freshController.initialize();

    await tester.pumpWidget(TaqwaTrackApp(controller: freshController));
    await settleApp(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Willkommen bei TAQWA TRACK'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-name')),
      'Yusuf',
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-language')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Türkçe'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('TAQWA TRACK’e hoş geldin'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(fresh.settings.onboarded, isTrue);
    expect(fresh.settings.name, 'Yusuf');
    expect(fresh.settings.language, 'tr');
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('Ana sayfa'), findsOneWidget);
  });

  testWidgets('Startseite zeigt Ramadan-Countdown und Gebete lassen sich '
      'abhaken', (tester) async {
    await tester.pumpWidget(TaqwaTrackApp(controller: controller));
    await settleApp(tester);

    expect(find.text('TAQWA TRACK'), findsOneWidget);
    expect(find.text('As-salāmu ʿalaykum'), findsOneWidget);
    expect(find.byType(RamadanCountdownCard), findsOneWidget);
    expect(find.text('RAMADAN-COUNTDOWN'), findsOneWidget);

    final fajr = find.byKey(const ValueKey('prayer-fajr'));
    await tester.ensureVisible(fajr);
    await tester.pump();
    await tester.tap(fajr);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(controller.settings!.xp, 10);
    expect(controller.prayers[Prayer.fajr], isTrue);

    for (final prayer in Prayer.values.skip(1)) {
      await controller.togglePrayerToday(prayer);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.allPrayersTodayDone, isTrue);
    expect(controller.goldCelebrationPending, isTrue);
    expect(find.text('GOLD'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();
    expect(controller.goldCelebrationPending, isFalse);
    expect(find.text('GOLD'), findsNothing);
  });

  testWidgets('Kalender hakt Habits ab', (tester) async {
    await tester.pumpWidget(TaqwaTrackApp(controller: controller));
    await settleApp(tester);

    await tapNav(tester, 'Kalender');
    expect(find.text('Habit-Tracker'), findsOneWidget);
    expect(find.text('Qur’an lesen'), findsWidgets);

    final habit = find.byKey(const ValueKey('habit-1-2026-10-30'));
    await tester.ensureVisible(habit);
    await tester.pump();
    await tester.tap(habit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(controller.settings!.xp, 5);
    expect(controller.todayHabits[1], HabitStatus.done);
  });

  testWidgets('Family koppelt per Code und löst die Kopplung wieder', (
    tester,
  ) async {
    await tester.pumpWidget(TaqwaTrackApp(controller: controller));
    await settleApp(tester);

    await tapNav(tester, 'Family');
    expect(find.text('TEST01'), findsOneWidget);
    expect(find.text('Noch keine Kopplung'), findsOneWidget);

    await tester.tap(find.text('Code manuell eingeben'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).last, 'FRIEND1');
    await tester.tap(find.text('Verbinden'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(controller.partners, hasLength(1));
    expect(controller.partners.single.code, 'FRIEND1');
    expect(find.text('Noch keine Kopplung'), findsNothing);

    // SnackBar ausblenden, damit sie das Drei-Punkte-Menü nicht überdeckt.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));

    final menu = find.byIcon(Icons.more_vert);
    await tester.ensureVisible(menu);
    await tester.pump();
    await tester.tap(menu);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Kopplung lösen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Lösen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.partners, isEmpty);
    expect(find.text('Noch keine Kopplung'), findsOneWidget);
  });

  testWidgets('Gebete-Tab zeigt Tages-Habits, Hadith und 1/5', (tester) async {
    await tester.pumpWidget(TaqwaTrackApp(controller: controller));
    await settleApp(tester);

    await tapNav(tester, 'Gebete');
    expect(find.text('Tages-Habits'), findsOneWidget);
    expect(find.textContaining('HEUTE ·'), findsOneWidget);
    expect(find.text('0/5'), findsWidgets);

    final fajr = find.byKey(const ValueKey('habit-fajr'));
    await tester.ensureVisible(fajr);
    await tester.tap(fajr);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.todayPrayers[Prayer.fajr], isTrue);
    expect(find.text('1/5'), findsWidgets);

    for (final prayer in Prayer.values.skip(1)) {
      await controller.togglePrayerToday(prayer);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.allPrayersTodayDone, isTrue);
    expect(find.text('5/5'), findsWidgets);
    expect(find.textContaining('MashaAllah'), findsOneWidget);
  });

  testWidgets('Tasbih zählt Dhikr und lässt sich zurücksetzen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: taqwaTheme(),
        home: TasbihScreen(controller: controller),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('tasbih-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.settings!.tasbihCount, 1);

    await tester.tap(find.byKey(const ValueKey('tasbih-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.settings!.tasbihCount, 2);

    await controller.resetTasbih();
    await tester.pump();
    expect(controller.settings!.tasbihCount, 0);
  });

  testWidgets('Quran-Bibliothek lädt Suren und Lesezeichen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: taqwaTheme(),
        home: QuranScreen(controller: controller),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Quran'), findsOneWidget);
    expect(find.text('Sure suchen …'), findsOneWidget);
    expect(find.text('Al-Faatiha'), findsOneWidget);

    expect(await controller.toggleBookmark(1, 1), isTrue);
    expect(controller.isBookmarked(1, 1), isTrue);
    expect(await controller.toggleBookmark(1, 1), isFalse);
    expect(controller.isBookmarked(1, 1), isFalse);
  });

  testWidgets('Hadith-Bibliothek ist offline durchsuchbar', (tester) async {
    final all = await HadithLibrary.load();
    expect(all.length, greaterThanOrEqualTo(60));
    expect(HadithLibrary.prayerOfTheDay(all, DateTime(2026, 10, 30)).isPrayer,
        isTrue);

    await tester.pumpWidget(
      MaterialApp(theme: taqwaTheme(), home: const HadithListScreen()),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Hadith-Bibliothek'), findsOneWidget);
    expect(
      find.text('Hadithe durchsuchen (z. B. Gebet, Geduld) …'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).first, 'Gebet');
    await tester.pump();
    expect(find.textContaining('Gebet'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'xyz-kein-treffer');
    await tester.pump();
    expect(find.text('Keine Hadithe gefunden.'), findsOneWidget);
  });

  testWidgets('Datenschutz und FAQ sind erreichbar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: taqwaTheme(), home: const PrivacyPolicyScreen()),
    );
    await tester.pump();
    expect(find.text('DATENSCHUTZERKLÄRUNG'), findsOneWidget);
    expect(find.textContaining('ausschließlich auf deinem Gerät'),
        findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(theme: taqwaTheme(), home: const FaqScreen()),
    );
    await tester.pump();
    expect(find.text('Häufige Fragen'), findsOneWidget);
    expect(
      find.text('Funktioniert TAQWA TRACK ohne Internet?'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text(supportEmail),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(supportEmail), findsOneWidget);
  });

  testWidgets('OLED-Modus und Sprache wirken sofort', (tester) async {
    await tester.pumpWidget(TaqwaTrackApp(controller: controller));
    await settleApp(tester);

    await controller.setOled(true);
    await tester.pump();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.scaffoldBackgroundColor, TaqwaColors.oledBackground);

    await controller.setLanguage('en');
    await tester.pump();
    expect(find.text('Prayers'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);

    await controller.setOled(false);
    await controller.setLanguage('de');
    await tester.pump();
  });

  test('Ramadan-Countdown zeigt auf einen zukünftigen 1. Ramadan', () {
    final from = DateTime(2026, 10, 30);
    final start = nextRamadanStart(from);
    expect(start.isAfter(from), isTrue);
    expect(start.difference(from).inDays, greaterThan(0));
    expect(start.difference(from).inDays, lessThan(400));

    final h = HijriCalendar.fromDate(start);
    expect(h.hMonth, 9);
    expect(h.hDay, 1);

    // Auch mitten im Ramadan bleibt der nächste Beginn in der Zukunft.
    final during = DateTime(2026, 3, 1);
    expect(nextRamadanStart(during).isAfter(during), isTrue);
  });

  test('QR-Snapshot überträgt den Fortschritt verlustfrei', () {
    const snapshot = ProfileSnapshot(
      code: 'K7QF2M',
      name: 'Aisha Müller',
      prayerMask: '10101',
      habitsDone: 3,
      habitsTotal: 5,
      streak: 12,
      day: '2026-10-30',
      reminderAt: '2026-10-30T18:00:00.000',
      reminderText: 'Bitte bete Maghrib – ich denke an dich.',
    );
    final parsed = ProfileSnapshot.tryParse(snapshot.encode());
    expect(parsed, isNotNull);
    expect(parsed!.code, snapshot.code);
    expect(parsed.name, snapshot.name);
    expect(parsed.prayerMask, snapshot.prayerMask);
    expect(parsed.prayersDone, 3);
    expect(parsed.habitsDone, 3);
    expect(parsed.streak, 12);
    expect(parsed.reminderText, snapshot.reminderText);
    expect(ProfileSnapshot.tryParse('https://example.com'), isNull);
  });
}

Future<void> tapNav(WidgetTester tester, String label) async {
  final target = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
  expect(target, findsOneWidget);
  await tester.tap(target);
  await settleApp(tester);
}

Future<void> settleApp(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
