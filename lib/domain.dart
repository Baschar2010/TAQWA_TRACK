import 'dart:math' as math;

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

