import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa_track/domain.dart';

void main() {
  group('level boundaries', () {
    test('uses the specified level 1, 2, and 3 XP ranges', () {
      expect(levelForXp(0), 1);
      expect(levelForXp(299), 1);
      expect(levelForXp(300), 2);
      expect(levelForXp(599), 2);
      expect(levelForXp(600), 3);
      expect(levelForXp(999), 3);
      expect(levelForXp(1000), 4);
    });

    test('uses 500 XP intervals from level 4 onward', () {
      expect(levelFloor(4), 1000);
      expect(levelCeiling(4), 1500);
      expect(levelForXp(1499), 4);
      expect(levelForXp(1500), 5);
    });
  });

  test(
    'Adhan calculates five ordered local prayer times for Duisburg offline',
    () {
      final schedule = PrayerSchedule.calculate(
        date: DateTime(2026, 10, 30),
        latitude: 51.4344,
        longitude: 6.7623,
        method: 'muslim_world_league',
        hanafi: true,
      );
      final times = Prayer.values
          .map((prayer) => schedule.times[prayer]!)
          .toList();
      expect(times, hasLength(5));
      for (var i = 1; i < times.length; i++) {
        expect(times[i].isAfter(times[i - 1]), isTrue);
      }
      expect(schedule.nextPrayer(DateTime(2026, 10, 30, 4)), Prayer.fajr);
      expect(schedule.nextPrayer(DateTime(2026, 10, 30, 23, 59)), isNull);
    },
  );
}
