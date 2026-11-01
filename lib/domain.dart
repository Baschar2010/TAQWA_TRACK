import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';

enum Prayer { fajr, dhuhr, asr, maghrib, isha }

enum HabitStatus { empty, done, partial, missed }

const prayerNames = <Prayer, String>{
  Prayer.fajr: 'Fajr',
  Prayer.dhuhr: 'Dhuhr',
  Prayer.asr: 'Asr',
  Prayer.maghrib: 'Maghrib',
  Prayer.isha: 'Isha',
};

String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Gebete, deren Zeit bereits begonnen hat, die im geteilten Stand aber noch
/// offen sind. Die kurze Schonfrist verhindert eine Erinnerung genau zum
/// Adhan – man soll erst in Ruhe beten können.
List<Prayer> missingDuePrayers({
  required String prayerMask,
  required Map<Prayer, DateTime> times,
  required DateTime now,
  Duration grace = const Duration(minutes: 10),
}) {
  final result = <Prayer>[];
  for (var index = 0; index < Prayer.values.length; index++) {
    final prayer = Prayer.values[index];
    if (index < prayerMask.length && prayerMask[index] == '1') continue;
    final time = times[prayer];
    if (time == null) continue;
    if (now.isAfter(time.add(grace))) result.add(prayer);
  }
  return result;
}

/// Beginn des nächsten Ramadan (1. Ramadan, 00:00).
DateTime nextRamadanStart(DateTime from) {
  final hijri = HijriCalendar.fromDate(from);
  var start = hijri.hijriToGregorian(hijri.hYear, 9, 1);
  final today = DateTime(from.year, from.month, from.day);
  if (!start.isAfter(today)) {
    start = hijri.hijriToGregorian(hijri.hYear + 1, 9, 1);
  }
  return DateTime(start.year, start.month, start.day);
}

int levelForXp(int xp) {
  if (xp < 300) return 1;
  if (xp < 600) return 2;
  if (xp < 1000) return 3;
  return 4 + ((xp - 1000) ~/ 500);
}

int levelFloor(int level) {
  if (level <= 1) return 0;
  if (level == 2) return 300;
  if (level == 3) return 600;
  return 1000 + ((level - 4) * 500);
}

int levelCeiling(int level) {
  if (level == 1) return 300;
  if (level == 2) return 600;
  if (level == 3) return 1000;
  return 1000 + ((level - 3) * 500);
}

class AppSettings {
  const AppSettings({
    required this.name,
    required this.xp,
    required this.streak,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.lastCompletedDay,
    required this.calculationMethod,
    required this.hanafi,
    this.profileId = '',
    this.onboarded = false,
    this.language = 'de',
    this.oled = false,
    this.themeMode = 'system',
    this.adhanEnabled = false,
    this.adhanMinutesBefore = 0,
    this.familyAlerts = true,
    this.tasbihCount = 0,
    this.tasbihTarget = 33,
    this.outboxReminderAt,
    this.outboxReminderText,
    this.goldDay,
  });

  final String name;
  final int xp;
  final int streak;
  final String locationName;
  final double latitude;
  final double longitude;
  final String? lastCompletedDay;
  final String calculationMethod;
  final bool hanafi;
  final String profileId;
  final bool onboarded;

  /// Sprachcode (z. B. 'de', 'ar', 'en'), der beim Onboarding gewählt wurde.
  final String language;

  /// Echtes Schwarz (OLED) statt dunkelgrauem Hintergrund.
  final bool oled;

  /// Gewünschtes Erscheinungsbild: `system`, `light` oder `dark`.
  final String themeMode;

  /// Lokale Erinnerungen zu den Gebetszeiten.
  final bool adhanEnabled;

  /// Minuten vor dem Gebet, zu denen erinnert wird (0 = zur Gebetszeit).
  final int adhanMinutesBefore;

  /// Erinnerungen und Nachrichten aus der Familie als Benachrichtigung
  /// anzeigen. Auch bei `false` bleiben die Nachrichten in der App sichtbar.
  final bool familyAlerts;

  final int tasbihCount;
  final int tasbihTarget;

  /// Noch nicht zugestellte Erinnerung für den Partner. Wird mit dem
  /// eigenen QR-Code übertragen.
  final String? outboxReminderAt;
  final String? outboxReminderText;

  /// Tag, an dem die Gold-Animation zuletzt gezeigt wurde.
  final String? goldDay;

  AppSettings copyWith({
    String? name,
    int? xp,
    int? streak,
    String? locationName,
    double? latitude,
    double? longitude,
    String? lastCompletedDay,
    String? calculationMethod,
    bool? hanafi,
    String? profileId,
    bool? onboarded,
    String? language,
    bool? oled,
    String? themeMode,
    bool? adhanEnabled,
    int? adhanMinutesBefore,
    bool? familyAlerts,
    int? tasbihCount,
    int? tasbihTarget,
    String? outboxReminderAt,
    String? outboxReminderText,
    String? goldDay,
    bool clearOutbox = false,
  }) => AppSettings(
    name: name ?? this.name,
    xp: xp ?? this.xp,
    streak: streak ?? this.streak,
    locationName: locationName ?? this.locationName,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    lastCompletedDay: lastCompletedDay ?? this.lastCompletedDay,
    calculationMethod: calculationMethod ?? this.calculationMethod,
    hanafi: hanafi ?? this.hanafi,
    profileId: profileId ?? this.profileId,
    onboarded: onboarded ?? this.onboarded,
    language: language ?? this.language,
    oled: oled ?? this.oled,
    themeMode: themeMode ?? this.themeMode,
    adhanEnabled: adhanEnabled ?? this.adhanEnabled,
    adhanMinutesBefore: adhanMinutesBefore ?? this.adhanMinutesBefore,
    familyAlerts: familyAlerts ?? this.familyAlerts,
    tasbihCount: tasbihCount ?? this.tasbihCount,
    tasbihTarget: tasbihTarget ?? this.tasbihTarget,
    outboxReminderAt: clearOutbox
        ? null
        : (outboxReminderAt ?? this.outboxReminderAt),
    outboxReminderText: clearOutbox
        ? null
        : (outboxReminderText ?? this.outboxReminderText),
    goldDay: goldDay ?? this.goldDay,
  );
}

class PrayerSchedule {
  PrayerSchedule({
    required this.date,
    required this.times,
    required this.sunrise,
    required this.imsak,
  });

  final DateTime date;
  final Map<Prayer, DateTime> times;
  final DateTime sunrise;
  final DateTime imsak;

  factory PrayerSchedule.calculate({
    required DateTime date,
    required double latitude,
    required double longitude,
    required String method,
    required bool hanafi,
  }) {
    final calculation = switch (method) {
      'karachi' => CalculationMethod.karachi.getParameters(),
      'egyptian' => CalculationMethod.egyptian.getParameters(),
      'umm_al_qura' => CalculationMethod.umm_al_qura.getParameters(),
      'north_america' => CalculationMethod.north_america.getParameters(),
      _ => CalculationMethod.muslim_world_league.getParameters(),
    };
    calculation.madhab = hanafi ? Madhab.hanafi : Madhab.shafi;
    final result = PrayerTimes(
      Coordinates(latitude, longitude, validate: true),
      DateComponents.from(date),
      calculation,
    );
    return PrayerSchedule(
      date: date,
      times: {
        Prayer.fajr: result.fajr,
        Prayer.dhuhr: result.dhuhr,
        Prayer.asr: result.asr,
        Prayer.maghrib: result.maghrib,
        Prayer.isha: result.isha,
      },
      sunrise: result.sunrise,
      imsak: result.fajr.subtract(const Duration(minutes: 10)),
    );
  }

  Prayer? nextPrayer(DateTime now) {
    for (final prayer in Prayer.values) {
      if (times[prayer]!.isAfter(now)) return prayer;
    }
    return null;
  }
}

String formatClock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// Koordinaten der Kaaba in Mekka.
const kaabaLatitude = 21.4225;
const kaabaLongitude = 39.8262;

/// Peilung (0–360°) von der eigenen Position zur Kaaba, gemessen von Norden
/// im Uhrzeigersinn.
double qiblaBearing(double latitude, double longitude) {
  final phi1 = latitude * math.pi / 180;
  final phi2 = kaabaLatitude * math.pi / 180;
  final deltaLon = (kaabaLongitude - longitude) * math.pi / 180;
  final y = math.sin(deltaLon);
  final x =
      math.cos(phi1) * math.tan(phi2) - math.sin(phi1) * math.cos(deltaLon);
  final degrees = math.atan2(y, x) * 180 / math.pi;
  return (degrees + 360) % 360;
}

/// Luftlinie zur Kaaba in Kilometern.
double distanceToKaaba(double latitude, double longitude) {
  const earthRadius = 6371.0;
  final phi1 = latitude * math.pi / 180;
  final phi2 = kaabaLatitude * math.pi / 180;
  final deltaPhi = (kaabaLatitude - latitude) * math.pi / 180;
  final deltaLon = (kaabaLongitude - longitude) * math.pi / 180;
  final a =
      math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
      math.cos(phi1) *
          math.cos(phi2) *
          math.sin(deltaLon / 2) *
          math.sin(deltaLon / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

const _profileAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Erzeugt einen kurzen, eindeutigen Kopplungscode (z. B. "K7QF2M").
String generateProfileCode([math.Random? random]) {
  final rnd = random ?? math.Random.secure();
  return List.generate(
    6,
    (_) => _profileAlphabet[rnd.nextInt(_profileAlphabet.length)],
  ).join();
}

/// Inhalt des persönlichen QR-Codes.
///
/// Der Code enthält neben der Kennung einen Schnappschuss des heutigen
/// Fortschritts. Beim Scannen werden beide Profile verknüpft und der
/// Fortschritt ohne Internet übertragen.
class ProfileSnapshot {
  const ProfileSnapshot({
    required this.code,
    required this.name,
    required this.prayerMask,
    required this.habitsDone,
    required this.habitsTotal,
    required this.streak,
    required this.day,
    this.reminderAt,
    this.reminderText,
    this.syncHost,
    this.syncPort,
  });

  static const prefix = 'TT2';
  static const defaultReminder = 'Zeit fürs Gebet – denk an deine Gebete.';

  final String code;
  final String name;

  /// Fünf Zeichen ('0'/'1') in der Reihenfolge Fajr … Isha.
  final String prayerMask;
  final int habitsDone;
  final int habitsTotal;
  final int streak;
  final String day;
  final String? reminderAt;
  final String? reminderText;

  /// Lokale IP-Adresse für die direkte Geräte-zu-Geräte-Kopplung im WLAN.
  final String? syncHost;
  final int? syncPort;

  List<Prayer> get prayers => [
    for (var i = 0; i < Prayer.values.length; i++)
      if (i < prayerMask.length && prayerMask[i] == '1') Prayer.values[i],
  ];

  int get prayersDone => prayerMask.split('').where((c) => c == '1').length;

  ProfileSnapshot withSync({String? host, int? port}) => ProfileSnapshot(
    code: code,
    name: name,
    prayerMask: prayerMask,
    habitsDone: habitsDone,
    habitsTotal: habitsTotal,
    streak: streak,
    day: day,
    reminderAt: reminderAt,
    reminderText: reminderText,
    syncHost: host ?? syncHost,
    syncPort: port ?? syncPort,
  );

  String encode() => [
    prefix,
    code,
    Uri.encodeComponent(name),
    prayerMask,
    '$habitsDone',
    '$habitsTotal',
    '$streak',
    day,
    reminderAt == null ? '' : Uri.encodeComponent(reminderAt!),
    reminderText == null ? '' : Uri.encodeComponent(reminderText!),
    syncHost ?? '',
    syncPort == null ? '' : '$syncPort',
  ].join('|');

  /// Liest einen gescannten QR-Inhalt. Gibt null zurück, wenn der Inhalt
  /// nicht zu TAQWA TRACK gehört. Ungültige Codes dürfen niemals eine
  /// Ausnahme auslösen – der Scanner darf an beliebigem Inhalt nicht crashen.
  static ProfileSnapshot? tryParse(String raw) {
    try {
      final parts = raw.trim().split('|');
      if (parts.length < 8 || parts[0] != prefix) return null;
      final mask = parts[3];
      if (mask.length != Prayer.values.length ||
          mask.split('').any((c) => c != '0' && c != '1')) {
        return null;
      }
      final code = parts[1].trim();
      if (code.isEmpty) return null;
      final habitsDone = int.tryParse(parts[4]) ?? 0;
      final habitsTotal = int.tryParse(parts[5]) ?? 0;
      final streak = int.tryParse(parts[6]) ?? 0;
      final port = parts.length > 11 ? int.tryParse(parts[11]) : null;
      return ProfileSnapshot(
        code: code,
        name: _decode(parts[2]).trim(),
        prayerMask: mask,
        habitsDone: habitsDone.clamp(0, habitsTotal),
        habitsTotal: habitsTotal,
        streak: streak,
        day: parts[7],
        reminderAt: parts.length > 8 && parts[8].isNotEmpty
            ? _decode(parts[8])
            : null,
        reminderText: parts.length > 9 && parts[9].isNotEmpty
            ? _decode(parts[9])
            : null,
        syncHost: parts.length > 10 && parts[10].isNotEmpty
            ? parts[10].trim()
            : null,
        syncPort: port != null && port > 0 && port <= 65535 ? port : null,
      );
    } catch (_) {
      return null;
    }
  }

  static String _decode(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }
}

/// Art einer kurzen Nachricht zwischen gekoppelten Geräten.
enum FamilyPingKind { nudge, message }

/// Nachricht, die ohne Server direkt über das lokale WLAN an ein
/// gekoppeltes Familienmitglied geht: eine Gebets-Erinnerung oder ein
/// kurzer persönlicher Text.
class FamilyPing {
  const FamilyPing({
    required this.fromCode,
    required this.fromName,
    required this.kind,
    this.prayer,
    this.text = '',
    this.sentAt,
  });

  static const prefix = 'TTMSG1';

  final String fromCode;
  final String fromName;
  final FamilyPingKind kind;
  final Prayer? prayer;
  final String text;
  final String? sentAt;

  String get sender {
    final name = fromName.trim();
    return name.isEmpty ? 'Deine Familie' : name;
  }

  /// Text, wie er in der Nachrichtenliste des Empfängers steht.
  String get displayText => switch (kind) {
    FamilyPingKind.nudge => 'Bitte vergesse $_prayerName nicht',
    FamilyPingKind.message => text.trim(),
  };

  String get notificationTitle => switch (kind) {
    FamilyPingKind.nudge => '$sender erinnert dich an $_prayerName',
    FamilyPingKind.message => '$sender schreibt dir',
  };

  String get notificationBody => switch (kind) {
    FamilyPingKind.nudge =>
      'Bitte vergesse $_prayerName nicht – möge Allah es annehmen.',
    FamilyPingKind.message =>
      text.trim().isEmpty
          ? 'Denk an deine Gebete – ich bin bei dir.'
          : text.trim(),
  };

  String get _prayerName =>
      prayer == null ? 'dein Gebet' : prayerNames[prayer]!;

  String encode() => [
    prefix,
    fromCode,
    Uri.encodeComponent(fromName),
    kind.name,
    prayer?.name ?? '',
    Uri.encodeComponent(text),
    sentAt ?? '',
  ].join('|');

  /// Liest eine empfangene Nachricht. Ungültige Pakete ergeben `null` und
  /// dürfen niemals eine Ausnahme auslösen.
  static FamilyPing? tryParse(String raw) {
    try {
      final parts = raw.trim().split('|');
      if (parts.length < 5 || parts[0] != prefix) return null;
      final fromCode = parts[1].trim();
      if (fromCode.isEmpty) return null;
      final kind = FamilyPingKind.values.asNameMap()[parts[3]];
      if (kind == null) return null;
      final prayer = Prayer.values.asNameMap()[parts[4]];
      return FamilyPing(
        fromCode: fromCode,
        fromName: _decodePing(parts[2]).trim(),
        kind: kind,
        prayer: prayer,
        text: parts.length > 5 ? _decodePing(parts[5]) : '',
        sentAt: parts.length > 6 && parts[6].isNotEmpty ? parts[6] : null,
      );
    } catch (_) {
      return null;
    }
  }

  static String _decodePing(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }
}

/// Gespeicherte Nachricht eines gekoppelten Geräts.
class FamilyMessage {
  const FamilyMessage({
    required this.id,
    required this.partnerCode,
    required this.direction,
    required this.kind,
    required this.text,
    required this.createdAt,
    this.prayer,
  });

  final int id;
  final String partnerCode;

  /// `in` für empfangene, `out` für selbst gesendete Nachrichten.
  final String direction;
  final String kind;
  final String text;
  final String? prayer;
  final String createdAt;

  bool get incoming => direction == 'in';

  Prayer? get prayerValue => Prayer.values.asNameMap()[prayer];

  DateTime? get time => DateTime.tryParse(createdAt);
}
