import 'package:adhan/adhan.dart';

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
  );
}

class PrayerSchedule {
  PrayerSchedule({required this.date, required this.times});

  final DateTime date;
  final Map<Prayer, DateTime> times;

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
