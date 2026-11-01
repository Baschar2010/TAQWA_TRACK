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

    test('direct family messages and the partner address persist', () async {
      final repo = memoryRepository();
      const snapshot = ProfileSnapshot(
        code: 'K7QF2M',
        name: 'Aisha',
        prayerMask: '10000',
        habitsDone: 1,
        habitsTotal: 3,
        streak: 4,
        day: '2026-10-30',
        syncHost: '192.168.1.42',
        syncPort: 48765,
      );
      final partner = await repo.savePartnerSnapshot(snapshot);
      expect(partner.syncHost, '192.168.1.42');
      expect(partner.syncPort, 48765);
      expect(partner.canReceiveDirectly, isTrue);

      await repo.saveFamilyMessage(
        partnerCode: partner.code,
        direction: 'out',
        kind: 'nudge',
        text: 'Bitte vergesse Fajr nicht',
        prayer: 'fajr',
        createdAt: DateTime(2026, 10, 30, 12),
      );
      await repo.saveFamilyMessage(
        partnerCode: partner.code,
        direction: 'in',
        kind: 'message',
        text: 'Danke, ich bete jetzt',
        createdAt: DateTime(2026, 10, 30, 12, 3),
      );

      final messages = await repo.familyMessages(partner.code);
      expect(messages, hasLength(2));
      expect(messages.first.text, 'Danke, ich bete jetzt');
      expect(messages.first.incoming, isTrue);
      expect(messages.last.prayerValue, Prayer.fajr);
      expect((await repo.familyMessages(partner.code, limit: 1)).length, 1);

      // Ein QR-Code ohne WLAN-Daten darf die bekannte Adresse nicht löschen.
      await repo.savePartnerSnapshot(
        const ProfileSnapshot(
          code: 'K7QF2M',
          name: 'Aisha',
          prayerMask: '11000',
          habitsDone: 2,
          habitsTotal: 3,
          streak: 5,
          day: '2026-10-31',
        ),
      );
      final refreshed = (await repo.partners()).single;
      expect(refreshed.syncHost, '192.168.1.42');
      expect(refreshed.syncPort, 48765);

      await repo.unlinkPartner(partner.id);
      expect(await repo.familyMessages(partner.code), isEmpty);
      await repo.close();
    });

    test(
      'family alerts are enabled by default and can be switched off',
      () async {
        final repo = memoryRepository();
        expect((await repo.loadSettings()).familyAlerts, isTrue);
        await repo.updateSettings(familyAlerts: false);
        expect((await repo.loadSettings()).familyAlerts, isFalse);
        await repo.updateSettings(familyAlerts: true);
        expect((await repo.loadSettings()).familyAlerts, isTrue);
        await repo.close();
      },
    );
  });
}
