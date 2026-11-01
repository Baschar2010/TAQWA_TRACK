import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_info.dart';
import 'theme.dart';

/// Inhalt einer Feedback-Nachricht, unabhängig von der Oberfläche.
class FeedbackDraft {
  const FeedbackDraft({
    required this.rating,
    required this.message,
    this.name = '',
  });

  /// 0 = keine Sterne vergeben, 1–5 = Bewertung.
  final int rating;
  final String message;
  final String name;

  bool get isEmpty => rating == 0 && message.trim().isEmpty;
}

const _ratingLabels = <int, String>{
  1: 'Verbesserungsbedarf',
  2: 'Geht so',
  3: 'Gut',
  4: 'Sehr gut',
  5: 'Ausgezeichnet',
};

String feedbackSubject(FeedbackDraft draft) => draft.rating > 0
    ? 'TAQWA TRACK Feedback · ${draft.rating}/5 Sterne'
    : 'TAQWA TRACK Feedback';

String feedbackMailBody(FeedbackDraft draft) {
  final stars = draft.rating > 0
      ? '${'★' * draft.rating}${'☆' * (5 - draft.rating)} (${draft.rating}/5)'
      : 'Keine Sterne vergeben';
  final buffer = StringBuffer()
    ..writeln('TAQWA TRACK – Feedback')
    ..writeln('Bewertung: $stars')
    ..writeln('Version: $appVersion (Build $appBuild)');
  if (draft.name.trim().isNotEmpty) {
    buffer.writeln('Von: ${draft.name.trim()}');
  }
  buffer
    ..writeln()
    ..writeln('Nachricht:')
    ..writeln(
      draft.message.trim().isEmpty ? '(keine Nachricht)' : draft.message.trim(),
    );
  return buffer.toString();
}

Uri feedbackMailUri(FeedbackDraft draft) => Uri.parse(
  'mailto:$supportEmail'
  '?subject=${Uri.encodeComponent(feedbackSubject(draft))}'
  '&body=${Uri.encodeComponent(feedbackMailBody(draft))}',
);

/// Standardversand über das E-Mail-Programm des Geräts.
Future<bool> sendFeedbackByMail(FeedbackDraft draft) async {
  try {
    return await launchUrl(
      feedbackMailUri(draft),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

typedef FeedbackSender = Future<bool> Function(FeedbackDraft draft);

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, this.initialName = '', this.onSend});

  final String initialName;
  final FeedbackSender? onSend;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  final TextEditingController _message = TextEditingController();
  int _rating = 0;
  bool _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final draft = FeedbackDraft(
      rating: _rating,
      message: _message.text,
      name: _name.text,
    );
    if (draft.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte vergib Sterne oder schreibe ein paar Worte.'),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    final sent = await (widget.onSend ?? sendFeedbackByMail)(draft);
    if (!mounted) return;
    setState(() => _sending = false);

    if (!sent) {
      await Clipboard.setData(ClipboardData(text: feedbackMailBody(draft)));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kein E-Mail-Programm gefunden. Feedback kopiert – bitte an '
            '$supportEmail senden.',
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1810),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF6B4D20)),
        ),
        title: const Row(
          children: [
            Icon(Icons.favorite, color: TaqwaColors.gold, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Danke für dein Feedback!',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: const Text(
          'Deine Nachricht wird direkt beim Entwickler landen. '
          'Barakallahu feek – deine Meinung macht TAQWA TRACK besser.',
          style: TextStyle(
            color: TaqwaColors.muted,
            fontSize: 11,
            height: 1.55,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      _rating = 0;
      _message.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Feedback & Bewertung', style: TextStyle(fontSize: 15)),
      centerTitle: true,
    ),
    body: StarField(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const TaqwaCard(
              goldBorder: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow('DEINE MEINUNG ZÄHLT', color: TaqwaColors.gold),
                  SizedBox(height: 5),
                  Text(
                    'Wie gefällt dir TAQWA TRACK?',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Dein Feedback geht direkt an den Entwickler – ohne Konto, '
                    'ohne Werbung und ohne Weitergabe an Dritte.',
                    style: TextStyle(
                      color: TaqwaColors.muted,
                      fontSize: 10,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TaqwaCard(
              child: Column(
                children: [
                  const Eyebrow('DEINE BEWERTUNG'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var star = 1; star <= 5; star++)
                        IconButton(
                          key: ValueKey('feedback-star-$star'),
                          tooltip: '$star von 5 Sternen',
                          onPressed: () => setState(() => _rating = star),
                          iconSize: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          icon: Icon(
                            star <= _rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: star <= _rating
                                ? TaqwaColors.gold
                                : TaqwaColors.muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      _rating == 0
                          ? 'Tippe auf einen Stern'
                          : '${_ratingLabel(_rating)} · $_rating von 5',
                      key: ValueKey(_rating),
                      style: TextStyle(
                        color: _rating == 0
                            ? TaqwaColors.muted
                            : TaqwaColors.goldLight,
                        fontSize: 10,
                        fontWeight: _rating == 0
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TaqwaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('DEINE NACHRICHT'),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('feedback-name'),
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    maxLength: 60,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Name (optional)',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('feedback-message'),
                    controller: _message,
                    minLines: 4,
                    maxLines: 7,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 12, height: 1.5),
                    decoration: const InputDecoration(
                      labelText: 'Was gefällt dir? Was können wir verbessern?',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('feedback-send'),
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF17120A),
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  _sending ? 'Wird geöffnet …' : 'Feedback senden',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: TaqwaColors.gold,
                  foregroundColor: const Color(0xFF17120A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Beim Senden öffnet sich deine E-Mail-App mit einer fertigen '
              'Nachricht. Du kannst sie vor dem Absenden noch ändern.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: TaqwaColors.muted,
                fontSize: 8.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _ratingLabel(int rating) =>
    _ratingLabels[rating] ?? _ratingLabels[3] ?? 'Gut';
