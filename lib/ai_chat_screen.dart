import 'package:flutter/material.dart';

import 'ai_service.dart';
import 'language.dart';
import 'theme.dart';

/// Islamicischer KI-Chat (Sabr-AI-ähnlich): Frag den Chatbot zu Fragen rund um
/// den Islam, den Koran, Hadithe, Gebete und Alltagssituationen.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key, this.service});

  final AiService? service;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  late final AiService _service;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<({bool isUser, String text})> _messages = <({bool isUser, String text})>[];
  final List<Map<String, String>> _history = <Map<String, String>>[];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AiService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_messages.isEmpty) {
      final text = AppText.of(Localizations.localeOf(context).languageCode);
      _messages.add((isUser: false, text: text.aiChatGreeting));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _loading) return;
    final text = AppText.of(Localizations.localeOf(context).languageCode);
    setState(() {
      _messages.add((isUser: true, text: question));
      _controller.clear();
      _loading = true;
      _error = null;
    });
    _scrollToBottom();
    if (!_service.isConfigured) {
      if (!mounted) return;
      setState(() {
        _messages.add((isUser: false, text: text.aiChatErrorNoKey));
        _loading = false;
      });
      return;
    }
    try {
      _history.add({'role': 'user', 'content': question});
      final answer = await _service.ask(
        question: question,
        languageCode: Localizations.localeOf(context).languageCode,
        history: List<Map<String, String>>.from(_history),
      );
      _history.add({'role': 'assistant', 'content': answer});
      if (!mounted) return;
      setState(() {
        _messages.add((isUser: false, text: answer));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = text.aiChatError;
        _messages.add((isUser: false, text: text.aiChatError));
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(Localizations.localeOf(context).languageCode);
    final languageCode = Localizations.localeOf(context).languageCode;
    final isRtl = languageFor(languageCode).isRtl;    return Scaffold(
      appBar: AppBar(
        title: Text(text.aiChatTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              itemCount: _messages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final message = _messages[index];
                final textDirection =
                    isRtl ? TextDirection.rtl : TextDirection.ltr;
                return Row(
                  mainAxisAlignment:
                      message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: message.isUser
                              ? TaqwaColors.gold
                              : TaqwaColors.panel,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: message.isUser
                                ? TaqwaColors.goldBorder
                                : TaqwaColors.border,
                          ),
                        ),
                        child: Text(
                          message.text,
                          textDirection: textDirection,
                          style: TextStyle(
                            color: message.isUser
                                ? TaqwaColors.onGold
                                : TaqwaColors.text,
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              color: TaqwaColors.red.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                _error!,
                style: TextStyle(color: TaqwaColors.red, fontSize: 11),
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: text.aiChatPlaceholder,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: TaqwaColors.border),
                        ),
                        filled: true,
                        fillColor: TaqwaColors.field,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _loading ? Icons.hourglass_empty : Icons.send,
                      color: TaqwaColors.goldLight,
                    ),
                    onPressed: _loading ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
