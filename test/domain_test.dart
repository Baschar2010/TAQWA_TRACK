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

  group('Smart Prayer Nudge', () {
    final times = {
      for (final prayer in Prayer.values)
        prayer: DateTime(2026, 10, 30, 5 + prayer.index * 3),
    };

    test('meldet nur Gebete, deren Zeit vorbei ist und die offen sind', () {
      expect(
        missingDuePrayers(
          prayerMask: '00000',
          times: times,
          now: DateTime(2026, 10, 30, 4),
        ),
        isEmpty,
      );
      expect(
        missingDuePrayers(
          prayerMask: '00000',
          times: times,
          now: DateTime(2026, 10, 30, 6),
        ),
        [Prayer.fajr],
      );
      expect(
        missingDuePrayers(
          prayerMask: '10000',
          times: times,
          now: DateTime(2026, 10, 30, 12),
        ),
        [Prayer.dhuhr, Prayer.asr],
      );
      // Kleine Schonfrist: direkt zum Adhan wird noch nicht gedrängt.
      expect(
        missingDuePrayers(
          prayerMask: '00000',
          times: times,
          now: DateTime(2026, 10, 30, 5, 5),
        ),
        isEmpty,
      );
      expect(
        missingDuePrayers(
          prayerMask: '11111',
          times: times,
          now: DateTime(2026, 10, 30, 23),
        ),
        isEmpty,
      );
    });
  });

  group('FamilyPing', () {
    test('überträgt Gebets-Erinnerung und Text verlustfrei', () {
      const nudge = FamilyPing(
        fromCode: 'AAAAAA',
        fromName: 'Aisha Müller',
        kind: FamilyPingKind.nudge,
        prayer: Prayer.fajr,
        sentAt: '2026-10-30T12:00:00.000',
      );
      final parsed = FamilyPing.tryParse(nudge.encode());
      expect(parsed, isNotNull);
      expect(parsed!.fromCode, 'AAAAAA');
      expect(parsed.fromName, 'Aisha Müller');
      expect(parsed.kind, FamilyPingKind.nudge);
      expect(parsed.prayer, Prayer.fajr);
      expect(parsed.displayText, 'Bitte vergesse Fajr nicht');
      expect(parsed.notificationTitle, contains('Aisha Müller'));
      expect(parsed.notificationBody, contains('Fajr'));
      expect(parsed.notificationBody, contains('Allah'));

      const message = FamilyPing(
        fromCode: 'BBBBBB',
        fromName: 'Bilal',
        kind: FamilyPingKind.message,
        text: 'Bitte denk an Fajr ❤ | heute',
      );
      final parsedMessage = FamilyPing.tryParse(message.encode());
      expect(parsedMessage!.text, 'Bitte denk an Fajr ❤ | heute');
      expect(parsedMessage.displayText, 'Bitte denk an Fajr ❤ | heute');
      expect(parsedMessage.notificationTitle, 'Bilal schreibt dir');
      expect(parsedMessage.notificationBody, contains('❤'));
    });

    test('ignoriert kaputte Pakete und nutzt neutrale Texte', () {
      for (final raw in [
        '',
        'TTMSG1',
        'TTMSG1|CODE|Name',
        'TTMSG1||Name|nudge|fajr',
        'TTMSG1|CODE|Name|unbekannt|fajr',
        'TT2|CODE|Name|10101|1|5|3|2026-10-30',
      ]) {
        expect(FamilyPing.tryParse(raw), isNull, reason: raw);
      }
      const anonymous = FamilyPing(
        fromCode: 'CODE',
        fromName: '   ',
        kind: FamilyPingKind.message,
      );
      expect(anonymous.sender, 'Deine Familie');
      expect(anonymous.notificationBody, contains('Denk an deine Gebete'));

      const generic = FamilyPing(
        fromCode: 'CODE',
        fromName: 'Aisha',
        kind: FamilyPingKind.nudge,
      );
      expect(generic.displayText, 'Bitte vergesse dein Gebet nicht');
    });
  });

  test('FamilyMessage unterscheidet Eingang und Ausgang', () {
    const incoming = FamilyMessage(
      id: 1,
      partnerCode: 'AAAAAA',
      direction: 'in',
      kind: 'nudge',
      text: 'Bitte vergesse Fajr nicht',
      prayer: 'fajr',
      createdAt: '2026-10-30T12:00:00.000',
    );
    const outgoing = FamilyMessage(
      id: 2,
      partnerCode: 'AAAAAA',
      direction: 'out',
      kind: 'message',
      text: 'Danke',
      createdAt: '2026-10-30T12:01:00.000',
    );
    expect(incoming.incoming, isTrue);
    expect(incoming.prayerValue, Prayer.fajr);
    expect(incoming.time, DateTime(2026, 10, 30, 12));
    expect(outgoing.incoming, isFalse);
    expect(outgoing.prayerValue, isNull);
  });
}
