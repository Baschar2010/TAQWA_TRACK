import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fehlercodes, die die Chat-UI in verständliche, lokalisierte Meldungen
/// übersetzen kann.
class AiException implements Exception {
  const AiException(this.code);

  final String code;
}

/// Islamischer KI-Chat (OpenAI-kompatibler Chat-Completions-Endpunkt).
///
/// Konfiguration:
/// - `endpoint`: Basis-URL des OpenAI-kompatiblen Chat-Endpunkts
///   (z. B. OpenAI, OpenRouter, lokales Ollama-Setup).
/// - `apiKey`: API-Key des jeweiligen Anbieters.
/// - `model`: Modell-Name (z. B. `gpt-4o-mini`).
///
/// Ist kein API-Key gesetzt, ist der Service nicht nutzbar – die App bleibt
/// damit offline-first und benötigt keine Daten beim Start.
class AiService {
  AiService({
    this.endpoint = 'https://api.openai.com/v1/chat/completions',
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
  });

  final String endpoint;
  final String apiKey;
  final String model;

  bool get isConfigured => apiKey.trim().isNotEmpty && endpoint.trim().isNotEmpty;

  /// Beantwortet eine islamische Frage. Der System-Prompt sorgt dafür, dass
  /// die KI sich auf Islam, Koran, Hadith, Gebete und Alltagsfragen konzentriert
  /// und Quellenangaben (z. B. Sure/Hadith) nennt, wo möglich.
  Future<String> ask({
    required String question,
    required String languageCode,
    String? context,
  }) async {
    if (!isConfigured) throw const AiException('not_configured');

    final systemPrompt =
        'You are an Islamic assistant for Muslims around the world. '
        'Answer questions about Islam, the Quran (cite surahs and verses, '
        'e. g. "Surah Al-Fatiha, verse 1"), Hadith (cite the collection and '
        'number, e. g. "Sahih al-Bukhari, book of prayer"), daily prayers '
        '(salah), fasting, zakat and general worship. Use respectful and '
        'clear language. If the question is religious in nature, prefer '
        'scholarly sources. Keep answers concise and practical. '
        'The user writes in this language: ${languageCode == 'de' ? 'German' : languageCode == 'ar' ? 'Arabic' : 'English'}.';

    final body = <String, dynamic>{
      'model': model,
      'messages': <Map<String, dynamic>>[
        {'role': 'system', 'content': systemPrompt},
        if (context != null && context.trim().isNotEmpty)
          {'role': 'user', 'content': context},
        {'role': 'user', 'content': question},
      ],
    };

    final response = await http.post(
      Uri.parse(endpoint),
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (apiKey.trim().isNotEmpty) 'Authorization': 'Bearer ${apiKey.trim()}',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw AiException('http_${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const AiException('empty');
    }
    final first = choices.first;
    if (first is! Map<String, dynamic>) throw const AiException('empty');
    final message = first['message'];
    if (message is! Map<String, dynamic>) throw const AiException('empty');
    final content = message['content'];
    if (content is String && content.trim().isNotEmpty) {
      return content.trim();
    }
    throw const AiException('empty');
  }
}
