import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'app_controller.dart';
import 'data/taqwa_repository.dart';
import 'domain.dart';
import 'theme.dart';

/// Persönlicher QR-Code. Der Inhalt enthält Profil-Kennung, Name und den
/// heutigen Fortschritt, damit beim Scannen alles offline übertragen wird.
class ProfileQrCard extends StatelessWidget {
  const ProfileQrCard({
    super.key,
    required this.snapshot,
    this.size = 170,
    this.showCode = true,
  });
  final ProfileSnapshot snapshot;
  final double size;
  final bool showCode;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: QrImageView(
          data: snapshot.encode(),
          version: QrVersions.auto,
          size: size,
          backgroundColor: Colors.white,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
          eyeStyle: QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: TaqwaColors.onGold,
          ),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: TaqwaColors.onGold,
          ),
        ),
      ),
      if (showCode) ...[
        const SizedBox(height: 8),
        Text(
          'Kopplungscode',
          style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
        ),
        const SizedBox(height: 2),
        Text(
          snapshot.code,
          style: TextStyle(
            color: TaqwaColors.goldLight,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
          ),
        ),
      ],
    ],
  );
}

/// Öffnet den integrierten QR-Scanner und liefert den Inhalt zurück.
Future<String?> openQrScanner(BuildContext context) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrScannerScreen()),
    );

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text('QR-Code scannen'),
      actions: [
        IconButton(
          tooltip: 'Taschenlampe',
          onPressed: _controller.toggleTorch,
          icon: const Icon(Icons.flashlight_on_outlined, size: 20),
        ),
        IconButton(
          tooltip: 'Kamera wechseln',
          onPressed: _controller.switchCamera,
          icon: const Icon(Icons.cameraswitch_outlined, size: 20),
        ),
      ],
    ),
    body: Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => _ScannerError(error: error),
        ),
        Center(
          child: Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TaqwaColors.gold, width: 2),
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              'Halte den QR-Code deines Familienmitglieds in den Rahmen. '
              'Die Kopplung passiert sofort – ohne Internet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});
  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography_outlined,
              color: TaqwaColors.gold,
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              denied
                  ? 'Kamerazugriff wurde abgelehnt. Erlaube ihn in den Android-Einstellungen, um QR-Codes zu scannen.'
                  : 'Die Kamera konnte nicht gestartet werden.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Zurück'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kopplungsbereich im Family-Tab.
class PartnerSection extends StatelessWidget {
  const PartnerSection({super.key, required this.controller});
  final TaqwaController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final snapshot = c.profileSnapshot;
    final partners = c.partners;
    final pending = c.settings?.outboxReminderAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Dein Profil', trailing: 'QR-Kopplung'),
        TaqwaCard(
          goldBorder: true,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (snapshot.code.isNotEmpty)
                    ProfileQrCard(
                      snapshot: snapshot,
                      size: 116,
                      showCode: false,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow('DEIN QR-CODE', color: TaqwaColors.gold),
                        const SizedBox(height: 4),
                        Text(
                          snapshot.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          snapshot.code,
                          style: TextStyle(
                            color: TaqwaColors.goldLight,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Scanne den Code deines Familienmitglieds – danach seid ihr verknüpft und seht euren Fortschritt.',
                          style: TextStyle(
                            color: TaqwaColors.muted,
                            fontSize: 8,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => scanAndLink(context),
                  icon: const Icon(Icons.qr_code_scanner, size: 16),
                  label: const Text(
                    'QR-Code scannen',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: TaqwaColors.gold,
                    foregroundColor: TaqwaColors.onGold,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => _showCodeDialog(context),
                child: Text(
                  'Code manuell eingeben',
                  style: TextStyle(color: TaqwaColors.muted, fontSize: 9),
                ),
              ),
            ],
          ),
        ),
        if (pending != null) ...[
          const SizedBox(height: 8),
          TaqwaCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  size: 15,
                  color: TaqwaColors.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Deine Erinnerung wartet im QR-Code. Zeige ihn deinem Familienmitglied.',
                    style: TextStyle(
                      color: TaqwaColors.muted,
                      fontSize: 8,
                      height: 1.4,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: c.clearOutbox,
                  child: const Text(
                    'Zurücksetzen',
                    style: TextStyle(fontSize: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        SectionTitle(
          'Verknüpft',
          trailing: partners.isEmpty
              ? 'noch niemand'
              : '${partners.length} ${partners.length == 1 ? 'Person' : 'Personen'}',
        ),
        if (partners.isEmpty)
          TaqwaCard(
            child: Column(
              children: [
                Icon(Icons.qr_code_2, color: TaqwaColors.gold, size: 28),
                const SizedBox(height: 7),
                const Text(
                  'Noch keine Kopplung',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Einmal scannen genügt: Danach seht ihr eure Gebete und Habits gegenseitig.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: TaqwaColors.muted),
                ),
              ],
            ),
          )
        else
          for (final partner in partners)
            _PartnerCard(controller: c, partner: partner),
        const SizedBox(height: 10),
        TaqwaCard(
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: TaqwaColors.muted, size: 14),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ein Scan verbindet beide Seiten direkt über euer WLAN – ohne Server und ohne Internet. Klappt es nicht, zeigt die App deinen Code zum Nachscannen.',
                  style: TextStyle(
                    fontSize: 9,
                    color: TaqwaColors.muted,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> scanAndLink(BuildContext context) async {
    final raw = await openQrScanner(context);
    if (raw == null || !context.mounted) return;
    await _handlePayload(context, raw);
  }

  Future<void> _handlePayload(BuildContext context, String raw) async {
    try {
      final result = await controller.linkFromScan(raw);
      if (!context.mounted) return;
      final snapshot = result.snapshot;
      if (snapshot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.reason ?? 'Kein TAQWA-TRACK-QR-Code erkannt.'),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      final name = snapshot.name.trim().isEmpty
          ? 'dein Familienmitglied'
          : snapshot.name.trim();
      if (result.mutual) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gegenseitig verknüpft: Du siehst $name und $name sieht dich.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      if (snapshot.syncHost == null) {
        // Manuell eingegebener Code: die Gegenseite muss den eigenen Code
        // scannen, damit auch sie die Kopplung erhält.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Mit $name verknüpft. Damit $name dich auch sieht, scannt '
              '$name einmal deinen QR-Code.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      // Die Gegenseite war im WLAN nicht erreichbar: eigenen Code anbieten,
      // damit der zweite Scan die Verbindung auf beiden Geräten herstellt.
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: TaqwaColors.card,
        isScrollControlled: true,
        builder: (_) => _FallbackLinkSheet(
          snapshot: controller.profileSnapshot,
          partnerName: name,
        ),
      );
    } on StateError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showCodeDialog(BuildContext context) async {
    final payload = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _CodeDialog(),
    );
    if (payload == null || payload.isEmpty || !context.mounted) return;
    // Ein reiner Code enthält keinen Fortschritt – daraus einen Minimal-Snapshot
    // bauen, damit die Kopplung trotzdem funktioniert.
    final snapshot =
        ProfileSnapshot.tryParse(payload) ??
        ProfileSnapshot(
          code: payload.toUpperCase(),
          name: 'Partner',
          prayerMask: '00000',
          habitsDone: 0,
          habitsTotal: 0,
          streak: 0,
          day: dayKey(DateTime.now()),
        );
    await _handlePayload(context, snapshot.encode());
  }
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: TaqwaColors.card,
    title: const Text('Code eingeben', style: TextStyle(fontSize: 15)),
    content: TextField(
      controller: _input,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'Kopplungscode',
        hintText: 'z. B. K7QF2M',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _input.text.trim()),
        child: const Text('Verbinden'),
      ),
    ],
  );
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.controller, required this.partner});
  final TaqwaController controller;
  final Partner partner;

  @override
  Widget build(BuildContext context) {
    final stale = partner.snapshotDay != dayKey(DateTime.now());
    final missing = controller.nudgeablePrayers(partner);
    final messages = controller.messagesFor(partner.code);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TaqwaCard(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: TaqwaColors.chip,
                  foregroundColor: TaqwaColors.goldLight,
                  child: Text(
                    initials(partner.displayName),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partner.displayName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        partner.alias != null
                            ? 'Stand: ${_relative(partner.snapshotAt)} · eigener Name, nur hier'
                            : 'Stand: ${_relative(partner.snapshotAt)}'
                                  '${stale ? ' · gestern oder älter' : ''}',
                        style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: partner.canUseCloud
                      ? 'Cloud-Sync aktiv – Nachrichten kommen von überall an'
                      : 'Nur im WLAN erreichbar – QR-Code neu scannen',
                  child: Icon(
                    partner.canUseCloud
                        ? Icons.cloud_done_outlined
                        : Icons.wifi_tethering_error_outlined,
                    size: 13,
                    color: partner.canUseCloud
                        ? TaqwaColors.green
                        : TaqwaColors.muted,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Optionen',
                  color: TaqwaColors.card,
                  icon: Icon(
                    Icons.more_vert,
                    size: 16,
                    color: TaqwaColors.muted,
                  ),
                  onSelected: (value) async {
                    switch (value) {
                      case 'scan':
                        await scanPartnerAgain(context);
                      case 'rename':
                        await _renamePartner(context);
                      case 'remind':
                        await controller.sendReminder(partner);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Erinnerung gespeichert – sie wird beim nächsten QR-Scan übertragen.',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      case 'remove':
                        await _confirmUnlink(context);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'remind',
                      child: Text(
                        'Erinnerung senden',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'scan',
                      child: Text(
                        'Status aktualisieren (QR)',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(
                        'Umbenennen (nur hier)',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        'Kopplung lösen',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(child: Eyebrow('GEBETE HEUTE')),
                Text(
                  '${partner.prayersDone}/5',
                  style: TextStyle(
                    color: TaqwaColors.goldLight,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                for (final prayer in Prayer.values) ...[
                  if (prayer.index != 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: partner.prayerDone(prayer)
                            ? TaqwaColors.green
                            : TaqwaColors.border,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: partner.prayerDone(prayer)
                              ? TaqwaColors.green
                              : TaqwaColors.border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          prayerNames[prayer]!.substring(0, 1),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: partner.prayerDone(prayer)
                                ? Colors.white
                                : TaqwaColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                const Expanded(child: Eyebrow('STANDARD-HABITS')),
                Text(
                  partner.habitsTotal == 0
                      ? '–'
                      : '${partner.habitsDone}/${partner.habitsTotal}',
                  style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: partner.habitsTotal == 0
                    ? 0
                    : partner.habitsDone / partner.habitsTotal,
                minHeight: 5,
                backgroundColor: TaqwaColors.border,
                color: TaqwaColors.gold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 12,
                  color: TaqwaColors.gold,
                ),
                const SizedBox(width: 4),
                Text(
                  '${partner.streak} Tage Streak',
                  style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
                ),
                const Spacer(),
                if (partner.reminderAt != null)
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        size: 11,
                        color: TaqwaColors.green,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Erinnerung erhalten',
                        style: TextStyle(color: TaqwaColors.green, fontSize: 8),
                      ),
                    ],
                  ),
              ],
            ),
            if (partner.reminderText != null) ...[
              const SizedBox(height: 6),
              Text(
                '„${partner.reminderText}“',
                style: TextStyle(
                  color: TaqwaColors.green,
                  fontSize: 9,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 9),
            Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  size: 12,
                  color: TaqwaColors.gold,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Eyebrow(
                    missing.isEmpty
                        ? 'ALLE FÄLLIGEN GEBETE ABGEHAKT'
                        : 'NOCH OFFEN · JETZT ERINNERN',
                  ),
                ),
                if (stale)
                  Text(
                    'Stand älter',
                    style: TextStyle(color: TaqwaColors.muted, fontSize: 7.5),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (missing.isEmpty)
              Text(
                'MashaAllah – nichts offen. Du kannst trotzdem eine Nachricht '
                'schicken.',
                style: TextStyle(
                  color: TaqwaColors.muted,
                  fontSize: 8,
                  height: 1.4,
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final prayer in missing)
                    _NudgeChip(
                      key: ValueKey('nudge-${partner.code}-${prayer.name}'),
                      label: '${prayerNames[prayer]} erinnern',
                      onTap: () => _sendNudge(context, prayer),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: ValueKey('partner-message-${partner.code}'),
                onPressed: () => _sendMessage(context),
                icon: const Icon(Icons.edit_note, size: 15),
                label: const Text(
                  'Nachricht senden',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: TaqwaColors.goldLight,
                  side: BorderSide(color: TaqwaColors.goldBorder),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
            if (messages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Divider(height: 1, color: TaqwaColors.border),
              const SizedBox(height: 6),
              for (final message in messages.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          message.incoming
                              ? Icons.call_received
                              : Icons.call_made,
                          size: 9,
                          color: message.incoming
                              ? TaqwaColors.green
                              : TaqwaColors.muted,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          message.text,
                          style: TextStyle(
                            color: message.incoming
                                ? TaqwaColors.green
                                : TaqwaColors.text,
                            fontSize: 8.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _relative(message.createdAt),
                        style: TextStyle(color: TaqwaColors.muted, fontSize: 7),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _sendNudge(BuildContext context, Prayer prayer) async {
    HapticFeedback.lightImpact();
    final sent = await controller.sendPrayerNudge(partner, prayer);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? '${prayerNames[prayer]}-Erinnerung ist bei '
                    '${partner.displayName} angekommen.'
              : 'Senden war gerade nicht möglich – prüfe deine '
                    'Internetverbindung und scannt zur Sicherheit einmal den '
                    'QR-Code neu.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _sendMessage(BuildContext context) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _MessageDialog(partnerName: partner.displayName),
    );
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    final sent = await controller.sendPartnerMessage(partner, text);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Nachricht an ${partner.displayName} gesendet.'
              : 'Die Nachricht konnte nicht zugestellt werden – prüfe deine '
                    'Internetverbindung und scannt zur Sicherheit einmal den '
                    'QR-Code neu.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> scanPartnerAgain(BuildContext context) async {
    final raw = await openQrScanner(context);
    if (raw == null || !context.mounted) return;
    try {
      final result = await controller.linkFromScan(raw);
      final snapshot = result.snapshot;
      if (snapshot != null && context.mounted) {
        final name = snapshot.name.trim().isEmpty
            ? 'deinem Familienmitglied'
            : snapshot.name.trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.mutual
                  ? 'Status gegenseitig mit $name aktualisiert.'
                  : 'Status von $name aktualisiert.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on StateError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _renamePartner(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          _RenameDialog(initial: partner.displayName, remoteName: partner.name),
    );
    if (result == null) return;
    await controller.renamePartner(partner.id, result);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.trim().isEmpty
              ? 'Spitzname entfernt. Es gilt wieder der Name deines Familienmitglieds.'
              : 'Name nur auf diesem Gerät geändert. ${partner.name} sieht weiterhin den eigenen Namen.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _confirmUnlink(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TaqwaColors.card,
        title: const Text('Kopplung lösen?', style: TextStyle(fontSize: 15)),
        content: Text(
          'Die Verbindung zu ${partner.displayName} wird entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Lösen'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.unlinkPartner(partner.id);
  }
}

/// Kleine Aktion für ein fälliges, noch offenes Gebet.
class _NudgeChip extends StatelessWidget {
  const _NudgeChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: TaqwaColors.chip,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TaqwaColors.goldBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_active_outlined,
            size: 11,
            color: TaqwaColors.goldLight,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: TaqwaColors.goldLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Kurze persönliche Nachricht an ein gekoppeltes Gerät.
class _MessageDialog extends StatefulWidget {
  const _MessageDialog({required this.partnerName});

  final String partnerName;

  @override
  State<_MessageDialog> createState() => _MessageDialogState();
}

class _MessageDialogState extends State<_MessageDialog> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: TaqwaColors.card,
    title: Text(
      'Nachricht an ${widget.partnerName}',
      style: const TextStyle(fontSize: 15),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('family-message-input'),
          controller: _input,
          autofocus: true,
          maxLength: 160,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Kurze Nachricht',
            hintText: 'z. B. Bitte denk an Fajr',
          ),
        ),
        Text(
          'Kommt direkt über euer WLAN an – ohne Server und ohne Internet.',
          style: TextStyle(color: TaqwaColors.muted, fontSize: 9, height: 1.45),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        key: const ValueKey('family-message-send'),
        onPressed: () => Navigator.pop(context, _input.text),
        child: const Text('Senden'),
      ),
    ],
  );
}

class _FallbackLinkSheet extends StatelessWidget {
  const _FallbackLinkSheet({required this.snapshot, required this.partnerName});

  final ProfileSnapshot snapshot;
  final String partnerName;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_tethering, color: TaqwaColors.gold, size: 26),
          const SizedBox(height: 8),
          const Text(
            'Noch nicht gegenseitig verknüpft',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '$partnerName war gerade nicht im selben WLAN erreichbar. '
            'Zeige $partnerName jetzt deinen QR-Code und lasse ihn einmal '
            'scannen – danach sehen euch beide Seiten.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: TaqwaColors.muted,
              fontSize: 10,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          if (snapshot.code.isNotEmpty)
            ProfileQrCard(snapshot: snapshot, size: 170),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: TaqwaColors.gold,
                foregroundColor: TaqwaColors.onGold,
              ),
              child: const Text('Fertig'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial, required this.remoteName});

  final String initial;
  final String remoteName;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _input = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: TaqwaColors.card,
    title: const Text('Umbenennen', style: TextStyle(fontSize: 15)),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _input,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(
            labelText: 'Dein Name für diese Person',
            hintText: 'z. B. Papa',
          ),
        ),
        Text(
          'Der Name gilt nur auf diesem Gerät. Der eigene Name der anderen '
          'Person bleibt unverändert.',
          style: TextStyle(color: TaqwaColors.muted, fontSize: 9, height: 1.45),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, ''),
        child: const Text('Zurücksetzen'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _input.text.trim()),
        child: const Text('Speichern'),
      ),
    ],
  );
}

String _relative(String? iso) {
  if (iso == null) return 'unbekannt';
  final time = DateTime.tryParse(iso);
  if (time == null) return 'unbekannt';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'gerade eben';
  if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
  if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
  return 'vor ${diff.inDays} Tagen';
}
