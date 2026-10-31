import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taqwa_track/data/taqwa_repository.dart';
import 'package:taqwa_track/domain.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  TaqwaRepository memoryRepository() =>
      TaqwaRepository(factory: databaseFactoryFfi, path: inMemoryDatabasePath);

  group('SQLite task persistence and XP rules', () {
    test(
      'prayers pay once; five prayers award completion and streak bonuses once',
      () async {
        final repo = memoryRepository();
        final day = DateTime(2026, 10, 30);
        final firstFour = [
          Prayer.fajr,
          Prayer.dhuhr,
          Prayer.asr,
          Prayer.maghrib,
        ];
        for (final prayer in firstFour) {
          expect((await repo.togglePrayer(day, prayer)).xpAdded, 10);
        }
        final fifth = await repo.togglePrayer(day, Prayer.isha);
        expect(
          fifth.xpAdded,
          40,
        ); // +10 prayer, +20 five-prayer bonus, +10 streak
        expect(fifth.streakAdvanced, isTrue);
        expect((await repo.loadSettings()).xp, 80);
        expect((await repo.loadSettings()).streak, 1);

        expect(
          (await repo.togglePrayer(day, Prayer.fajr)).xpAdded,
          0,
        ); // uncheck
        expect(
          (await repo.togglePrayer(day, Prayer.fajr)).xpAdded,
          0,
        ); // recheck cannot farm XP
        expect((await repo.loadSettings()).xp, 80);
        expect((await repo.loadSettings()).streak, 1);
        await repo.close();
      },
    );

    test(
      'habit XP is retained once per habit and date through status changes',
      () async {
        final repo = memoryRepository();
        final habitId = await repo.addHabit('Read Qur’an');
        final day = DateTime(2026, 10, 30);
        expect(
          (await repo.setHabitStatus(day, habitId, HabitStatus.done)).xpAdded,
          5,
        );
        expect(
          (await repo.setHabitStatus(day, habitId, HabitStatus.missed)).xpAdded,
          0,
        );
        expect(
          (await repo.setHabitStatus(day, habitId, HabitStatus.done)).xpAdded,
          0,
        );
        expect((await repo.loadSettings()).xp, 5);
        expect((await repo.habitStatuses(day))[habitId], HabitStatus.done);
        await repo.close();
      },
    );

    test(
      'location, calculation settings, and family prayer marks persist in SQLite',
      () async {
        final repo = memoryRepository();
        await repo.updateSettings(
          name: 'Hamza K.',
          locationName: 'Duisburg Mitte',
          latitude: 51.43,
          longitude: 6.76,
          calculationMethod: 'karachi',
          hanafi: false,
        );
        final memberId = await repo.addFamilyMember('Aisha');
        await repo.setFamilyPrayer(
          DateTime(2026, 10, 30),
          memberId,
          Prayer.fajr,
          true,
        );
        final settings = await repo.loadSettings();
        expect(settings.name, 'Hamza K.');
        expect(settings.locationName, 'Duisburg Mitte');
        expect(settings.calculationMethod, 'karachi');
        expect(settings.hanafi, isFalse);
        expect(
          (await repo.familyPrayerStatus(
            DateTime(2026, 10, 30),
            memberId,
          ))['fajr'],
          isTrue,
        );
        await repo.close();
      },
    );

    test('on-disk SQLite survives close and reopen', () async {
      final directory = await Directory.systemTemp.createTemp(
        'taqwa-track-test-',
      );
      final path = '${directory.path}${Platform.pathSeparator}persist.sqlite';
      final first = TaqwaRepository(factory: databaseFactoryFfi, path: path);
      await first.updateSettings(name: 'Hamza Persisted');
      await first.close();
      final reopened = TaqwaRepository(factory: databaseFactoryFfi, path: path);
      expect((await reopened.loadSettings()).name, 'Hamza Persisted');
      await reopened.close();
      await directory.delete(recursive: true);
    });
  });
}
