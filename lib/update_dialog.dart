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
    barrierDismissible: true,
    builder: (_) =>
        UpdateDialog(release: release, currentVersion: currentVersion),
  );
  if (accepted != true) return false;

  final target = Uri.tryParse(release.apkUrl);
  final open = launcher ?? launchExternal;
  if (target != null && await open(target)) return true;

  await Clipboard.setData(ClipboardData(text: release.apkUrl));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Download-Link kopiert: ${release.apkUrl}')),
    );
  }
  return false;
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
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1A12), Color(0xFF12100B)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF6B4D20)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
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
                    color: const Color(0xFF1B160D),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/branding/logo.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
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
                      const Eyebrow('NEUES UPDATE', color: TaqwaColors.gold),
                      const SizedBox(height: 2),
                      Text(
                        'Version ${release.version} ist da',
                        style: const TextStyle(
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
              style: const TextStyle(
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
                  color: const Color(0xFF15130D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: TaqwaColors.border),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    notes,
                    style: const TextStyle(
                      color: TaqwaColors.muted,
                      fontSize: 9.5,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.info_outline, size: 12, color: TaqwaColors.muted),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Die APK wird in deinem Browser heruntergeladen.',
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
                      foregroundColor: const Color(0xFF17120A),
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
