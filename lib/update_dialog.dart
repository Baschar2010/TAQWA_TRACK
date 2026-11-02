import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_info.dart';
import 'theme.dart';
import 'update_service.dart';

/// Öffnet einen Link außerhalb der App. Gibt `false` zurück, wenn kein
/// Browser gefunden wurde – dann wird der Link stattdessen kopiert.
typedef LinkLauncher = Future<bool> Function(Uri uri);

Future<bool> launchExternal(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Zeigt den Update-Dialog und startet auf Wunsch den Download. Der Dialog
/// liefert `true`, wenn „Jetzt aktualisieren“ gewählt wurde.
Future<bool> showUpdateDialog(
  BuildContext context, {
  required ReleaseInfo release,
  String currentVersion = appVersion,
  LinkLauncher? launcher,
}) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        UpdateDialog(release: release, currentVersion: currentVersion),
  );
  if (accepted != true) return false;

  // Test-/Override-Pfad: externer Launcher (z. B. im Widget-Test).
  if (launcher != null) {
    final target = Uri.tryParse(release.apkUrl);
    if (target != null && await launcher(target)) return true;
    await Clipboard.setData(ClipboardData(text: release.apkUrl));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download-Link kopiert: ${release.apkUrl}')),
      );
    }
    return false;
  }

  // Produktionspfad: APK herunterladen und Android-Installationsdialog öffnen.
  if (!context.mounted) return false;
  return _downloadAndInstall(context, release);
}

Future<bool> _downloadAndInstall(BuildContext context, ReleaseInfo release) async {
  final progress = ValueNotifier<double>(0);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, value, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value: value > 0 ? value : null,
              color: TaqwaColors.gold,
            ),
            const SizedBox(height: 14),
            Text(
              'Update wird heruntergeladen … ${(value * 100).round()} %',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );

  final ok = await UpdateService.downloadAndInstallUpdate(
    release,
    onProgress: (p) => progress.value = p,
  );

  if (context.mounted) {
    Navigator.of(context).pop();
  }
  progress.dispose();

  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Update konnte nicht heruntergeladen/installiert werden.'),
      ),
    );
  }
  return ok;
}

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({
    super.key,
    required this.release,
    required this.currentVersion,
  });

  final ReleaseInfo release;
  final String currentVersion;

  @override
  Widget build(BuildContext context) {
    final notes = _cleanNotes(release.notes);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [TaqwaColors.panel, TaqwaColors.panelDeep],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: TaqwaColors.goldBorder),
          boxShadow: [
            BoxShadow(
              color: TaqwaColors.shadow,
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: TaqwaColors.gold),
                    color: TaqwaColors.chip,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/branding/logo.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.system_update,
                        color: TaqwaColors.goldLight,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow('NEUES UPDATE', color: TaqwaColors.gold),
                      const SizedBox(height: 2),
                      Text(
                        'Version ${release.version} ist da',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: TaqwaColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Du nutzt Version $currentVersion. Aktualisiere jetzt, um alle '
              'Verbesserungen und Fehlerbehebungen zu erhalten.',
              style: TextStyle(
                color: TaqwaColors.muted,
                fontSize: 11,
                height: 1.55,
              ),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 132),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TaqwaColors.panelDeep,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: TaqwaColors.border),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    notes,
                    style: TextStyle(
                      color: TaqwaColors.muted,
                      fontSize: 9.5,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 12, color: TaqwaColors.muted),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Die APK wird heruntergeladen und installiert.',
                    style: TextStyle(color: TaqwaColors.muted, fontSize: 8.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: TaqwaColors.muted,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Später',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text(
                      'Jetzt aktualisieren',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: TaqwaColors.gold,
                      foregroundColor: TaqwaColors.onGold,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Entfernt die gröbsten Markdown-Zeichen aus GitHub-Release-Notizen.
String _cleanNotes(String raw) {
  final lines = raw
      .split('\n')
      .map(
        (line) => line
            .replaceAll(RegExp(r'^#{1,6}\s*'), '')
            .replaceAll('**', '')
            .replaceAll('__', '')
            .trimRight(),
      )
      .where((line) => line.trim().isNotEmpty)
      .toList();
  final text = lines.join('\n').trim();
  if (text.length <= 600) return text;
  return '${text.substring(0, 597).trimRight()} …';
}
