import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'language.dart';
import 'theme.dart';

/// Willkommens-Setup beim ersten Start: Name und Sprache.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});
  final TaqwaController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  late String _language = widget.controller.settings?.language ?? 'de';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = AppText.of(_language).nameHint);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await widget.controller.completeOnboarding(name: name, language: _language);
  }

  Future<void> _pickLanguage() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TaqwaColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => _LanguageSheet(current: _language),
    );
    if (picked != null) setState(() => _language = picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(_language);
    final language = languageFor(_language);
    final rtl = language.isRtl;
    return Scaffold(
      body: StarField(
        child: SafeArea(
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF3A2A11), Color(0xFF17130C)],
                            ),
                            border: Border.all(
                              color: TaqwaColors.gold,
                              width: 1.6,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x44E5A93C),
                                blurRadius: 28,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.mosque,
                            color: TaqwaColors.goldLight,
                            size: 38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Center(
                        child: Text(
                          'TAQWA TRACK',
                          style: TextStyle(
                            color: TaqwaColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        text.welcome,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        text.tagline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: TaqwaColors.muted,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TaqwaCard(
                        child: Column(
                          children: [
                            _Feature(
                              icon: Icons.wifi_off_rounded,
                              text: text.featureOffline,
                            ),
                            const SizedBox(height: 9),
                            _Feature(
                              icon: Icons.menu_book_outlined,
                              text: text.featureQuran,
                            ),
                            const SizedBox(height: 9),
                            _Feature(
                              icon: Icons.qr_code_2,
                              text: text.featureFamily,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Eyebrow(text.nameLabel),
                      const SizedBox(height: 7),
                      TextField(
                        key: const ValueKey('onboarding-name'),
                        controller: _name,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _finish(),
                        decoration: InputDecoration(
                          hintText: text.nameHint,
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            size: 18,
                            color: TaqwaColors.gold,
                          ),
                          errorText: _error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Eyebrow(text.languageLabel),
                      const SizedBox(height: 7),
                      InkWell(
                        key: const ValueKey('onboarding-language'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: _pickLanguage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141311),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: TaqwaColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.language,
                                size: 18,
                                color: TaqwaColors.gold,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  language.nativeName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                language.englishName,
                                style: const TextStyle(
                                  color: TaqwaColors.muted,
                                  fontSize: 9,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.expand_more,
                                size: 18,
                                color: TaqwaColors.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey('onboarding-start'),
                          onPressed: _saving ? null : _finish,
                          style: FilledButton.styleFrom(
                            backgroundColor: TaqwaColors.gold,
                            foregroundColor: const Color(0xFF17120A),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF17120A),
                                  ),
                                )
                              : Text(
                                  text.start,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            size: 12,
                            color: TaqwaColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              text.privacyNote,
                              style: const TextStyle(
                                color: TaqwaColors.muted,
                                fontSize: 8,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF211A0D),
          border: Border.all(color: TaqwaColors.border),
        ),
        child: Icon(icon, size: 14, color: TaqwaColors.goldLight),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(text, style: const TextStyle(fontSize: 10, height: 1.4)),
      ),
    ],
  );
}

class _LanguageSheet extends StatefulWidget {
  const _LanguageSheet({required this.current});
  final String current;

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final visible = appLanguages.where((language) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return language.nativeName.toLowerCase().contains(q) ||
          language.englishName.toLowerCase().contains(q) ||
          language.code.contains(q);
    }).toList();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: TaqwaColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.language, size: 16, color: TaqwaColors.gold),
                    SizedBox(width: 8),
                    Text(
                      'Sprache wählen · Choose language',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'Suchen · Search …',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 17,
                      color: TaqwaColors.gold,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 14),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFF242220)),
                  itemBuilder: (context, index) {
                    final language = visible[index];
                    final selected = language.code == widget.current;
                    return ListTile(
                      dense: true,
                      onTap: () => Navigator.pop(context, language.code),
                      leading: SizedBox(
                        width: 28,
                        child: Text(
                          language.code.toUpperCase(),
                          style: TextStyle(
                            color: selected
                                ? TaqwaColors.goldLight
                                : TaqwaColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        language.nativeName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? TaqwaColors.goldLight
                              : TaqwaColors.text,
                        ),
                      ),
                      subtitle: Text(
                        language.englishName,
                        style: const TextStyle(
                          fontSize: 8,
                          color: TaqwaColors.muted,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: TaqwaColors.gold,
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
