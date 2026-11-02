import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'cloud_sync.dart';
import 'data/taqwa_repository.dart';
import 'domain.dart';
import 'notifications.dart';

/// Eindeutiger Name des periodischen Hintergrund-Auftrags.
const backgroundTaskName = 'taqwa-cloud-sync';

/// Wird von Android im Hintergrund aufgerufen – auch wenn die App geschlossen
/// ist. Der Abgleich läuft höchstens alle 15 Minuten (Android-Vorgabe).
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await runCloudPull();
    } catch (error) {
      debugPrint('Hintergrund-Abgleich fehlgeschlagen: $error');
    }
    // `true`, damit Android den Auftrag nicht in eine Fehlerschleife schickt.
    return true;
  });
}

/// Meldet den periodischen Cloud-Abgleich einmalig an. Fehler dürfen den
/// App-Start nie verhindern.
Future<void> setupBackgroundSync() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await Workmanager().initialize(backgroundCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      backgroundTaskName,
      backgroundTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  } catch (error) {
    debugPrint('Hintergrund-Abgleich konnte nicht angemeldet werden: $error');
  }
}

/// Ein einzelner Abgleich ohne laufende App. Wird sowohl vom Hintergrund-
/// Auftrag als auch von Tests genutzt.
Future<int> runCloudPull() async {
  final repository = TaqwaRepository();
  try {
    final settings = await repository.ensureProfile();
    if (!settings.cloudEnabled || settings.cloudInboxKey.isEmpty) return 0;
    final relay = NtfyCloudRelay();
    var delivered = 0;
    try {
      final result = await relay.fetch(
        inboxKey: settings.cloudInboxKey,
        cursor: settings.cloudCursor,
      );
      for (final envelope in result.envelopes) {
        if (await handleCloudEnvelope(repository, settings, envelope)) {
          delivered++;
        }
      }
      final cursor = result.cursor;
      if (cursor != null && cursor != settings.cloudCursor) {
        await repository.updateSettings(cloudCursor: cursor);
      }
    } finally {
      relay.close();
    }
    return delivered;
  } finally {
    await repository.close();
  }
}

/// Verarbeitet eine Cloud-Nachricht ohne geladenen Controller.
///
/// Gibt `true` zurück, wenn eine neue Familien-Nachricht gespeichert wurde.
Future<bool> handleCloudEnvelope(
  TaqwaRepository repository,
  AppSettings settings,
  CloudEnvelope envelope,
) async {
  if (envelope.fromCode.isEmpty || envelope.fromCode == settings.profileId) {
    return false;
  }

  final partners = await repository.partners();
  Partner? partner;
  for (final item in partners) {
    if (item.code == envelope.fromCode) partner = item;
  }

  // Neue Kopplung: Das andere Gerät hat unseren QR-Code gescannt.
  if (envelope.type == 'hello') {
    final snapshot = envelope.snapshot;
    if (snapshot != null) await repository.savePartnerSnapshot(snapshot);
    return false;
  }

  // Nur bereits gekoppelte Geräte dürfen Nachrichten schicken.
  if (partner == null) return false;

  if (envelope.type == 'status') {
    final snapshot = envelope.snapshot;
    if (snapshot != null) await repository.savePartnerSnapshot(snapshot);
    return false;
  }

  final ping = envelope.toPing();
  if (ping == null) return false;
  await repository.saveFamilyMessage(
    partnerCode: partner.code,
    direction: 'in',
    kind: ping.kind.name,
    text: ping.displayText,
    prayer: ping.prayer?.name,
    createdAt: DateTime.now(),
  );
  if (settings.familyAlerts) {
    await NotificationService.showNow(
      title: ping.notificationTitle,
      body: ping.notificationBody,
      id: 9000 + (ping.fromCode.hashCode & 0xff),
    );
  }
  return true;
}
