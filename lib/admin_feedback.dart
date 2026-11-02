import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_info.dart';
import 'theme.dart';

/// Einzelner Feedback-Eintrag.
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

/// Admin-Konto (lokal gespeichert, ohne Passwort-Zwang).
class AdminAccount {
  AdminAccount({
    required this.name,
    this.isMain = false,
  });

  final String name;
  final bool isMain;

  Map<String, dynamic> toJson() => {
        'name': name,
        'isMain': isMain,
      };

  factory AdminAccount.fromJson(Map<String, dynamic> json) => AdminAccount(
        name: (json['name'] as String?) ?? '',
        isMain: json['isMain'] == true,
      );
}

/// Speicherung der Admin-Konten.
class AdminStorage {
  static Future<File?> _file() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/taqwa_admins.json');
    } catch (_) {
      return null;
    }
  }

  static Future<List<AdminAccount>> load() async {
    try {
      final f = await _file();
      if (f == null || !await f.exists()) return <AdminAccount>[];
      final text = await f.readAsString();
      if (text.trim().isEmpty) return <AdminAccount>[];
      final list = jsonDecode(text) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(AdminAccount.fromJson)
          .where((a) => a.name.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return <AdminAccount>[];
    }
  }

  static Future<void> save(List<AdminAccount> list) async {
    try {
      final f = await _file();
      if (f == null) return;
      await f.writeAsString(
        jsonEncode(list.map((a) => a.toJson()).toList()),
      );
    } catch (_) {}
  }

  static Future<void> upsert(AdminAccount account) async {
    final list = await load();
    list.removeWhere(
      (a) => a.name.toLowerCase() == account.name.trim().toLowerCase(),
    );
    list.add(account);
    await save(list);
  }

  static Future<void> remove(String name) async {
    final list = await load();
    list.removeWhere(
      (a) => a.name.toLowerCase() == name.trim().toLowerCase(),
    );
    await save(list);
  }
}

/// Speicherung der Feedbacks (JSON-Datei).
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
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final f = await _file();
      if (f != null && await f.exists()) await f.delete();
    } catch (_) {}
  }
}

/// Admin-Dashboard (ohne Passwort-Gate, nur versteckter Zugang).
class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  List<FeedbackEntry> _entries = <FeedbackEntry>[];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _reload();
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

  Future<void> _openAdminManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AdminManagementScreen(),
      ),
    );
  }

  Future<void> _contactDeveloper() async {
    final uri = Uri.parse(
      'mailto:alsafdibaschar5@gmail.com?subject=${Uri.encodeComponent('TAQWA TRACK - Passwort/Support')}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await Clipboard.setData(
        const ClipboardData(text: 'alsafdibaschar5@gmail.com'),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-Mail-Adresse kopiert.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin-Feedback', style: TextStyle(fontSize: 15)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Admins verwalten',
            onPressed: _openAdminManagement,
            icon: const Icon(Icons.admin_panel_settings),
          ),
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
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _contactDeveloper,
                      icon: const Icon(Icons.mail_outline, size: 16),
                      label: const Text(
                        'Passwort vergessen? Entwickler kontaktieren',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Verwaltungsseite für Admin-Konten.
class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  List<AdminAccount> _admins = <AdminAccount>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final list = await AdminStorage.load();
    if (!mounted) return;
    setState(() {
      _admins = list;
      _loading = false;
    });
  }

  Future<void> _addAdmin() async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neuen Admin anlegen'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Admin-Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Anlegen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Name erforderlich.');
      return;
    }
    await AdminStorage.upsert(AdminAccount(name: name, isMain: false));
    // Benachrichtigung an den Entwickler (best-effort).
    try {
      final uri = Uri.parse(
        'mailto:alsafdibaschar5@gmail.com?subject=${Uri.encodeComponent('TAQWA TRACK - Neuer Admin angelegt')}&body=${Uri.encodeComponent('Neuer Admin: $name')}',
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    await _reload();
    _snack('Admin „$name“ angelegt. Entwickler wurde benachrichtigt.');
  }

  Future<void> _remove(AdminAccount admin) async {
    if (admin.name.toLowerCase() == 'baschar') {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Haupt-Admin löschen?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dies löscht den Haupt-Admin unwiderruflich. '
                'Zur Bestätigung bitte den Namen „Baschar“ eingeben.',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(labelText: 'Name bestätigen'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Endgültig löschen'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      if (ctrl.text.trim() != admin.name) {
        _snack('Bestätigung fehlgeschlagen.');
        return;
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Konto „${admin.name}“ löschen?'),
          content: const Text(
            'Möchtest du dieses Konto wirklich unwiderruflich löschen? '
            'Alle zugehörigen Daten werden entfernt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Konto löschen'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    await AdminStorage.remove(admin.name);
    await _reload();
    _snack('Konto „${admin.name}“ gelöscht.');
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin-Verwaltung', style: TextStyle(fontSize: 15)),
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
                    Row(
                      children: [
                        Expanded(
                          child: Eyebrow('ADMIN-KONTEN', color: TaqwaColors.gold),
                        ),
                        FilledButton.icon(
                          onPressed: _addAdmin,
                          icon: const Icon(Icons.person_add, size: 16),
                          label: const Text(
                            'Hinzufügen',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: TaqwaColors.gold,
                            foregroundColor: TaqwaColors.onGold,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_admins.isEmpty)
                      TaqwaCard(
                        child: Text(
                          'Keine Admins vorhanden.',
                          style: TextStyle(color: TaqwaColors.muted, fontSize: 11),
                        ),
                      )
                    else
                      for (final admin in _admins) ...[
                        TaqwaCard(
                          child: Row(
                            children: [
                              Icon(
                                admin.isMain
                                    ? Icons.verified_user
                                    : Icons.person,
                                color: admin.isMain
                                    ? TaqwaColors.gold
                                    : TaqwaColors.muted,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      admin.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      admin.isMain
                                          ? 'Haupt-Admin'
                                          : 'Administrator',
                                      style: TextStyle(
                                        color: TaqwaColors.muted,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Konto löschen',
                                onPressed: () => _remove(admin),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                  ],
                ),
        ),
      ),
    );
  }
}
