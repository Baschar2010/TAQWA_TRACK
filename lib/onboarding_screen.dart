import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'app_controller.dart';
import 'domain.dart';
import 'theme.dart';

/// Inhalt des persönlichen QR-Codes zur Kopplung.
String profileQrPayload(String code, String name) =>
    'TAQWA-TRACK:$code:$name';

class ProfileQrCard extends StatelessWidget {
  const ProfileQrCard({
    super.key,
    required this.code,
    required this.name,
    this.size = 170,
  });
  final String code;
  final String name;
  final double size;

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
          data: profileQrPayload(code, name),
          version: QrVersions.auto,
          size: size,
          backgroundColor: Colors.white,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Color(0xFF151515),
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Color(0xFF151515),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Kopplungscode',
        style: const TextStyle(color: TaqwaColors.muted, fontSize: 8),
      ),
      const SizedBox(height: 2),
      Text(
        code,
        style: const TextStyle(
          color: TaqwaColors.goldLight,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 4,
        ),
      ),
    ],
  );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});
  final TaqwaController controller;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = TextEditingController();
  String? _code;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _code = generateProfileCode());
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    await widget.controller.completeOnboarding(
      _controller.text.trim(),
      code: _code,
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    return Scaffold(
      body: StarField(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: code == null ? _nameStep() : _qrStep(code),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nameStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Center(
        child: Icon(
          Icons.nightlight_round,
          color: TaqwaColors.goldLight,
          size: 42,
        ),
      ),
      const SizedBox(height: 14),
      const Center(
        child: Text(
          'TAQWA TRACK',
          style: TextStyle(
            color: TaqwaColors.goldLight,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
            fontSize: 18,
          ),
        ),
      ),
      const SizedBox(height: 6),
      const Center(
        child: Text(
          'Willkommen! Wie dürfen wir dich nennen?',
          textAlign: TextAlign.center,
          style: TextStyle(color: TaqwaColors.muted, fontSize: 11),
        ),
      ),
      const SizedBox(height: 22),
      TaqwaCard(
        goldBorder: true,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('DEIN NAME', color: TaqwaColors.gold),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _next(),
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'z. B. Hamza',
                prefixIcon: Icon(
                  Icons.person_outline,
                  size: 18,
                  color: TaqwaColors.gold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  backgroundColor: TaqwaColors.gold,
                  foregroundColor: const Color(0xFF17120A),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text(
                  'Weiter',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      const Center(
        child: Text(
          'Dein Name und dein persönlicher QR-Code bleiben auf diesem Gerät.',
          textAlign: TextAlign.center,
          style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
        ),
      ),
    ],
  );

  Widget _qrStep(String code) => Column(
    children: [
      const SizedBox(height: 6),
      const Eyebrow('DEIN PERSÖNLICHER QR-CODE', color: TaqwaColors.gold),
      const SizedBox(height: 6),
      Text(
        'As-salāmu ʿalaykum, ${_controller.text.trim()}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      const Text(
        'Mit diesem Code verbindet dich deine Familie einmalig.',
        textAlign: TextAlign.center,
        style: TextStyle(color: TaqwaColors.muted, fontSize: 9),
      ),
      const SizedBox(height: 16),
      TaqwaCard(
        goldBorder: true,
        padding: const EdgeInsets.all(16),
        child: ProfileQrCard(
          code: code,
          name: _controller.text.trim(),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _saving ? null : _finish,
          style: FilledButton.styleFrom(
            backgroundColor: TaqwaColors.gold,
            foregroundColor: const Color(0xFF17120A),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
          child: Text(
            _saving ? 'Einen Moment …' : 'Los geht’s',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
      ),
    ],
  );
}

/// Kopplungsbereich im Family-Tab: eigener QR-Code, Code-Eingabe und
/// Liste der verknüpften Partner.
class PartnerSection extends StatelessWidget {
  const PartnerSection({super.key, required this.controller});
  final TaqwaController controller;

  @override
  Widget build(BuildContext context) {
    final code = controller.settings?.profileId ?? '';
    final name = controller.settings?.name ?? '';
    final partners = controller.partners;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Kopplung', trailing: 'QR-Code'),
        TaqwaCard(
          goldBorder: true,
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (code.isNotEmpty)
                ProfileQrCard(code: code, name: name, size: 104),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('DEIN PROFIL', color: TaqwaColors.gold),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Lass deinen QR-Code einmalig von deinem Partner scannen – oder gib seinen Code hier ein.',
                      style: TextStyle(
                        color: TaqwaColors.muted,
                        fontSize: 8,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showLinkDialog(context, controller),
                        icon: const Icon(Icons.link, size: 14),
                        label: const Text(
                          'Partner koppeln',
                          style: TextStyle(fontSize: 10),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: TaqwaColors.goldLight,
                          side: const BorderSide(color: TaqwaColors.gold),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (partners.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final partner in partners)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TaqwaCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFF251C0E),
                      foregroundColor: TaqwaColors.goldLight,
                      child: Text(
                        initials(partner.name),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partner.name,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Gekoppelt · ${partner.code}',
                            style: const TextStyle(
                              color: TaqwaColors.muted,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kopplung lösen',
                      onPressed: () => _confirmUnlink(
                        context,
                        controller,
                        partner.id,
                        partner.name,
                      ),
                      icon: const Icon(Icons.link_off, size: 15),
                      color: TaqwaColors.muted,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _showLinkDialog(
    BuildContext context,
    TaqwaController controller,
  ) async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final linked = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TaqwaColors.card,
        title: const Text('Partner koppeln', style: TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Kopplungscode',
                hintText: 'z. B. K7QF2M',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'z. B. Aisha',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await controller.linkPartner(
                codeController.text,
                nameController.text,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext, ok);
            },
            child: const Text('Verbinden'),
          ),
        ],
      ),
    );
    codeController.dispose();
    nameController.dispose();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            linked == true
                ? 'Partner erfolgreich gekoppelt.'
                : 'Kopplung fehlgeschlagen – Code prüfen.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmUnlink(
    BuildContext context,
    TaqwaController controller,
    int id,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TaqwaColors.card,
        title: const Text('Kopplung lösen?', style: TextStyle(fontSize: 15)),
        content: Text('Die Verbindung zu $name wird entfernt.'),
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
    if (confirmed == true) await controller.unlinkPartner(id);
  }
}
