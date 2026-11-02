import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app_info.dart';
import 'theme.dart';

/// Ein einzelner Feedback-Eintrag.
class FeedbackEntry {
  FeedbackEntry({
    required this.rating,
    required this.message,
    this.name = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final int rating;
  final String message;
  final String name;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'rating': rating,
        'message': message,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FeedbackEntry.fromJson(Map<String, dynamic> json) => FeedbackEntry(
        rating: (json['rating'] as num?)?.toInt() ?? 0,
        message: (json['message'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

/// Lokale Speicherung der Feedbacks (JSON-Datei im App-Dokumentenverzeichnis).
class FeedbackStorage {
  static Future<File?> _file() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/taqwa_feedback.json');
    } catch (_) {
      return null;
    }
  }

  static Future<List<FeedbackEntry>> load() async {
    try {
      final f = await _file();
      if (f == null || !await f.exists()) return <FeedbackEntry>[];
      final text = await f.readAsString();
      if (text.trim().isEmpty) return <FeedbackEntry>[];
      final list = jsonDecode(text) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(FeedbackEntry.fromJson)
          .toList();
    } catch (_) {
      return <FeedbackEntry>[];
    }
  }

  static Future<void> save(FeedbackEntry entry) async {
    try {
      final list = await load();
      list.add(entry);
      final f = await _file();
      if (f == null) return;
      await f.writeAsString(jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (_) {
      // Speichern ist best-effort; die App darf dadurch nicht abstürzen.
    }
  }

  static Future<void> clear() async {
    try {
      final f = await _file();
      if (f != null && await f.exists()) await f.delete();
    } catch (_) {}
  }
}

/// Admin-Dashboard, geschützt durch einen PIN.
class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  static const _pin = '1234';

  bool _unlocked = false;
  final TextEditingController _pinController = TextEditingController();
  List<FeedbackEntry> _entries = <FeedbackEntry>[];
  bool _loading = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_pinController.text.trim() != _pin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falscher PIN.')),
      );
      return;
    }
    setState(() {
      _unlocked = true;
      _loading = true;
    });
    final list = await FeedbackStorage.load();
    if (!mounted) return;
    setState(() {
      _entries = list;
      _loading = false;
    });
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final list = await FeedbackStorage.load();
    if (!mounted) return;
    setState(() {
      _entries = list;
      _loading = false;
    });
  }

  String _summarize() {
    final buffer = StringBuffer()
      ..writeln('TAQWA TRACK – Feedback-Zusammenfassung')
      ..writeln('Version: $appVersion (Build $appBuild)')
      ..writeln('Anzahl: ${_entries.length}')
      ..writeln();
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      final stars = e.rating > 0
          ? '${'★' * e.rating}${'☆' * (5 - e.rating)} (${e.rating}/5)'
          : 'Keine Sterne';
      buffer
        ..writeln('--- Feedback ${i + 1} ---')
        ..writeln('Bewertung: $stars')
        ..writeln('Von: ${e.name.trim().isEmpty ? '(anonym)' : e.name.trim()}')
        ..writeln('Datum: ${e.createdAt.toIso8601String()}')
        ..writeln('Nachricht: ${e.message.trim().isEmpty ? '(keine)' : e.message.trim()}')
        ..writeln();
    }
    return buffer.toString();
  }

  Future<void> _copySummary() async {
    await Clipboard.setData(ClipboardData(text: _summarize()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zusammenfassung kopiert.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin-Feedback', style: TextStyle(fontSize: 15)),
          centerTitle: true,
        ),
        body: StarField(
          child: SafeArea(
            child: Center(
              child: TaqwaCard(
                goldBorder: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Eyebrow('GESCHÜTZTER BEREICH', color: TaqwaColors.gold),
                    const SizedBox(height: 8),
                    const Text(
                      'Admin-PIN eingeben',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'PIN'),
                      onSubmitted: (_) => _unlock(),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _unlock,
                      style: FilledButton.styleFrom(
                        backgroundColor: TaqwaColors.gold,
                        foregroundColor: TaqwaColors.onGold,
                      ),
                      child: const Text('Entsperren'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin-Feedback', style: TextStyle(fontSize: 15)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Neu laden',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StarField(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Eyebrow(
                      '${_entries.length} FEEDBACK(S)',
                      color: TaqwaColors.gold,
                    ),
                    const SizedBox(height: 8),
                    if (_entries.isEmpty)
                      TaqwaCard(
                        child: Text(
                          'Noch keine Feedbacks vorhanden.',
                          style: TextStyle(color: TaqwaColors.muted, fontSize: 11),
                        ),
                      )
                    else
                      for (final entry in _entries) ...[
                        TaqwaCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    entry.rating > 0
                                        ? '${'★' * entry.rating}${'☆' * (5 - entry.rating)}'
                                        : 'Keine Sterne',
                                    style: TextStyle(
                                      color: TaqwaColors.gold,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${entry.createdAt.day}.${entry.createdAt.month}.${entry.createdAt.year}',
                                    style: TextStyle(
                                      color: TaqwaColors.muted,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                              if (entry.name.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  entry.name.trim(),
                                  style: TextStyle(
                                    color: TaqwaColors.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (entry.message.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  entry.message.trim(),
                                  style: const TextStyle(fontSize: 11, height: 1.4),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _entries.isEmpty ? null : _copySummary,
                        icon: const Icon(Icons.content_copy, size: 16),
                        label: const Text(
                          'Feedbacks zusammenfassen',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: TaqwaColors.gold,
                          foregroundColor: TaqwaColors.onGold,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kopiert alle Feedbacks als Text in die Zwischenablage.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: TaqwaColors.muted, fontSize: 8.5),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
