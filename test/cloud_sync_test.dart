import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taqwa_track/app_controller.dart';
import 'package:taqwa_track/cloud_sync.dart';
import 'package:taqwa_track/data/taqwa_repository.dart';
import 'package:taqwa_track/domain.dart';
import 'package:taqwa_track/link_sync.dart';

/// Cloud-Ersatz für die Tests: ein gemeinsames „Netz“, in dem jedes Postfach
/// eine Liste von Nachrichten ist. Kein Socket, kein Internet.
class _FakeCloud implements CloudRelay {
  _FakeCloud(this.network);

  final Map<String, List<CloudEnvelope>> network;
  int published = 0;

  @override
  Future<bool> publish({
    required String inboxKey,
    required CloudEnvelope envelope,
  }) async {
    network.putIfAbsent(inboxKey, () => <CloudEnvelope>[]).add(envelope);
    published++;
    return true;
  }

  @override
  Future<CloudFetch> fetch({required String inboxKey, String? cursor}) async {
    final inbox = network[inboxKey] ?? const <CloudEnvelope>[];
    final seen = int.tryParse(cursor ?? '') ?? 0;
    return CloudFetch(
      envelopes: inbox.skip(seen).toList(),
      cursor: '${inbox.length}',
    );
  }

  @override
  void close() {}
}

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory directory;
  late Map<String, List<CloudEnvelope>> network;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('taqwa-cloud-');
    network = {};
  });

  tearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  Future<TaqwaController> device(String name, String code) async {
    final repository = TaqwaRepository(
      factory: databaseFactoryFfi,
      path: '${directory.path}${Platform.pathSeparator}$code.sqlite',
    );
    await repository.completeOnboarding(name, code);
    final controller = TaqwaController(
      repository,
      clock: () => DateTime(2026, 10, 30, 12),
      linkSync: LinkSyncService(allowDesktop: false),
      cloudRelay: _FakeCloud(network),
      cloudInterval: const Duration(hours: 1),
    );
    addTearDown(controller.dispose);
    addTearDown(controller.repository.close);
    await controller.initialize();
    return controller;
  }

  test('ein Scan koppelt beide Geräte über die Cloud', () async {
    final a = await device('Aisha', 'AAAAAA');
    final b = await device('Bilal', 'BBBBBB');

    // Jede Installation hat ein eigenes, zufälliges Cloud-Postfach.
    expect(a.settings!.cloudInboxKey, isNotEmpty);
    expect(b.settings!.cloudInboxKey, isNotEmpty);
    expect(a.settings!.cloudInboxKey, isNot(b.settings!.cloudInboxKey));

    await a.linkFromScan(b.profileSnapshot.encode());

    final paired = a.partners.single;
    expect(paired.code, 'BBBBBB');
    expect(paired.canUseCloud, isTrue);
    expect(paired.cloudKey, b.settings!.cloudInboxKey);

    // Der Gegenpart bekommt die Kopplung beim nächsten Abruf – ohne WLAN.
    await b.syncCloudNow();
    expect(b.partners.single.code, 'AAAAAA');
    expect(b.partners.single.cloudKey, a.settings!.cloudInboxKey);

    // Die Antwort mit dem eigenen Schlüssel kommt ebenfalls an.
    await a.syncCloudNow();
    expect(a.partners.single.cloudKey, b.settings!.cloudInboxKey);
  });

  test('Nudge und Nachricht laufen über die Cloud', () async {
    final a = await device('Aisha', 'AAAAAA');
    final b = await device('Bilal', 'BBBBBB');
    await a.linkFromScan(b.profileSnapshot.encode());
    await b.syncCloudNow();
    await a.syncCloudNow();

    // Fajr ist um 12:00 fällig und bei Bilal noch offen.
    expect(a.nudgeablePrayers(a.partners.single), contains(Prayer.fajr));
    expect(await a.sendPrayerNudge(a.partners.single, Prayer.fajr), isTrue);

    await b.syncCloudNow();
    final nudge = b.messagesFor('AAAAAA').first;
    expect(nudge.incoming, isTrue);
    expect(nudge.text, 'Bitte vergesse Fajr nicht');
    expect(nudge.prayerValue, Prayer.fajr);
    // Der Absender führt die Nachricht ebenfalls im Verlauf.
    expect(a.messagesFor('BBBBBB').first.text, 'Bitte vergesse Fajr nicht');

    expect(
      await b.sendPartnerMessage(b.partners.single, 'Danke, ich bete jetzt'),
      isTrue,
    );
    await a.syncCloudNow();
    expect(
      a.messagesFor('BBBBBB').any((m) => m.text == 'Danke, ich bete jetzt'),
      isTrue,
    );
  });

  test('Gebetsstatus wird über die Cloud abgeglichen', () async {
    final a = await device('Aisha', 'AAAAAA');
    final b = await device('Bilal', 'BBBBBB');
    await a.linkFromScan(b.profileSnapshot.encode());
    await b.syncCloudNow();

    // Aisha hakt zwei Gebete ab und teilt den Stand.
    await a.togglePrayerToday(Prayer.fajr);
    await a.togglePrayerToday(Prayer.dhuhr);
    await a.publishStatus();

    await b.syncCloudNow();
    expect(b.partners.single.prayerMask, '11000');
  });

  test('abgeschaltete Cloud sendet nichts mehr', () async {
    final a = await device('Aisha', 'AAAAAA');
    final b = await device('Bilal', 'BBBBBB');
    await a.linkFromScan(b.profileSnapshot.encode());
    await b.syncCloudNow();
    await a.syncCloudNow();

    await b.setCloudEnabled(false);
    expect(b.settings!.cloudEnabled, isFalse);

    final before = network[b.settings!.cloudInboxKey]!.length;
    await a.sendPrayerNudge(a.partners.single, Prayer.fajr);
    await b.syncCloudNow();
    expect(b.messagesFor('AAAAAA'), isEmpty);
    expect(network[b.settings!.cloudInboxKey], hasLength(before + 1));
  });

  test('unbekannte Absender werden ignoriert', () async {
    final a = await device('Aisha', 'AAAAAA');
    final stranger = await device('Fremd', 'ZZZZZZ');

    final strangerKey = a.settings!.cloudInboxKey;
    await stranger.cloudRelay.publish(
      inboxKey: strangerKey,
      envelope: CloudEnvelope.ping(
        const FamilyPing(
          fromCode: 'ZZZZZZ',
          fromName: 'Fremd',
          kind: FamilyPingKind.message,
          text: 'Hallo',
        ),
      ),
    );

    await a.syncCloudNow();
    expect(a.partners, isEmpty);
    expect(a.messagesFor('ZZZZZZ'), isEmpty);
  });
}
