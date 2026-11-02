import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

/// Admin-Konto (Passwort als SHA-256-Hash).
class AdminAccount {
  AdminAccount({
    required this.name,
    required this.passwordHash,
    this.isMain = false,
  });

  final String name;
  final String passwordHash;
  final bool isMain;

  Map<String, dynamic> toJson() => {
        'name': name,
        'passwordHash': passwordHash,
        'isMain': isMain,
      };

  factory AdminAccount.fromJson(Map<String, dynamic> json) => AdminAccount(
        name: (json['name'] as String?) ?? '',
        passwordHash: (json['passwordHash'] as String?) ?? '',
        isMain: json['isMain'] == true,
      );
}

/// Passwort-Reset-Anfrage eines Admins.
class ResetRequest {
  ResetRequest({required this.name, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  final String name;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ResetRequest.fromJson(Map<String, dynamic> json) => ResetRequest(
        name: (json['name'] as String?) ?? '',
        createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

String hashPassword(String password) =>
    sha256.convert(utf8.encode(password)).toString();

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

  static Future<AdminAccount?> find(String name) async {
    final list = await load();
    for (final a in list) {
      if (a.name.toLowerCase() == name.trim().toLowerCase()) return a;
    }
    return null;
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

  static Future<void> clear() async {
    try {
      final f = await _file();
      if (f != null && await f.exists()) await f.delete();
    } catch (_) {}
  }
}

/// Speicherung der Reset-Anfragen.
class ResetRequestStorage {
  static Future<File?> _file() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/taqwa_reset_requests.json');
    } catch (_) {
      return null;
    }
  }

  static Future<List<ResetRequest>> load() async {
    try {
      final f = await _file();
      if (f == null || !await f.exists()) return <ResetRequest>[];
      final text = await f.readAsString();
      if (text.trim().isEmpty) return <ResetRequest>[];
      final list = jsonDecode(text) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(ResetRequest.fromJson)
          .toList();
    } catch (_) {
      return <ResetRequest>[];
    }
  }

  static Future<void> add(String name) async {
    try {
      final list = await load();
      list.removeWhere(
        (r) => r.name.toLowerCase() == name.trim().toLowerCase(),
      );
      list.add(ResetRequest(name: name.trim()));
      final f = await _file();
      if (f == null) return;
      await f.writeAsString(
        jsonEncode(list.map((r) => r.toJson()).toList()),
      );
    } catch (_) {}
  }

  static Future<void> remove(String name) async {
    try {
      final list = await load();
      list.removeWhere(
        (r) => r.name.toLowerCase() == name.trim().toLowerCase(),
      );
      final f = await _file();
      if (f == null) return;
      await f.writeAsString(
        jsonEncode(list.map((r) => r.toJson()).toList()),
      );
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final f = await _file();
      if (f != null && await f.exists()) await f.delete();
    } catch (_) {}
  }
}

/// Speicherung der Feedbacks.
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

/// Admin-Dashboard mit Login (Haupt-Admin Baschar + Passwort).
class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  static const _mainAdminName = 'Baschar';

  bool _unlocked = false;
  bool _isMainAdmin = false;
  String _currentUser = '';
  bool _needsSetup = true;
  bool _loading = false;

  final TextEditingController _loginName = TextEditingController();
  final TextEditingController _loginPassword = TextEditingController();
  final TextEditingController _setupPassword = TextEditingController();
  final TextEditingController _setupConfirm = TextEditingController();

  List<FeedbackEntry> _entries = <FeedbackEntry>[];
  List<ResetRequest> _resetRequests = <ResetRequest>[];

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  @override
  void dispose() {
    _loginName.dispose();
    _loginPassword.dispose();
    _setupPassword.dispose();
    _setupConfirm.dispose();
    super.dispose();
  }

  Future<void> _checkSetup() async {
    final list = await AdminStorage.load();
    if (!mounted) return;
    setState(() {
      _needsSetup = !list.any((a) => a.isMain);
    });
  }

  Future<void> _setup() async {
    if (_setupPassword.text.trim().length < 4) {
      _snack('Passwort muss mindestens 4 Zeichen haben.');
      return;
    }
    if (_setupPassword.text != _setupConfirm.text) {
      _snack('Passwörter stimmen nicht überein.');
      return;
    }
    await AdminStorage.upsert(
      AdminAccount(
        name: _mainAdminName,
        passwordHash: hashPassword(_setupPassword.text),
        isMain: true,
      ),
    );
    if (!mounted) return;
    setState(() {
      _needsSetup = false;
      _unlocked = true;
      _isMainAdmin = true;
      _currentUser = _mainAdminName;
    });
    await _reload();
  }

  Future<void> _login() async {
    final name = _loginName.text.trim();
    final password = _loginPassword.text;
    if (name.isEmpty || password.isEmpty) {
      _snack('Name und Passwort eingeben.');
      return;
    }
    final account = await AdminStorage.find(name);
    if (account == null || account.passwordHash != hashPassword(password)) {
      _snack('Ungültige Anmeldedaten.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _unlocked = true;
      _isMainAdmin = account.isMain;
      _currentUser = account.name;
    });
    await _reload();
  }

  Future<void> _forgotPassword() async {
    final name = _loginName.text.trim();
    if (name.isEmpty) {
      _snack('Bitte zuerst den Admin-Namen eingeben.');
      return;
    }
    final account = await AdminStorage.find(name);
    if (account == null) {
      _snack('Admin nicht gefunden.');
      return;
    }
    // Reset-Anfrage speichern (für Haupt-Admin-Freigabe bei Sub-Admins).
    if (!account.isMain) {
      await ResetRequestStorage.add(name);
    }
    // E-Mail an Entwickler.
    final subject = account.isMain
        ? 'TAQWA TRACK - Passwort vergessen (Haupt-Admin)'
        : 'TAQWA TRACK - Passwort-Reset angefordert ($name)';
    final body = account.isMain
        ? 'Haupt-Admin Baschar hat Passwort-Reset angefordert.'
        : 'Admin "$name" hat Passwort-Reset angefordert. Bitte freigeben.';
    final uri = Uri.parse(
      'mailto:alsafdibaschar5@gmail.com?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: 'alsafdibaschar5@gmail.com'));
      _snack('E-Mail-Adresse kopiert.');
    }
    if (account.isMain) {
      _snack('Reset-Anfrage an Entwickler gesendet.');
    } else {
      _snack('Anfrage gesendet. Der Administrator wird benachrichtigt.');
    }
  }

  Future<void> _emergencyReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notfall-Reset'),
        content: const Text(
          'Alle Admin-Konten werden gelöscht. Danach muss das Haupt-Admin-Passwort neu festgelegt werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await AdminStorage.clear();
    await ResetRequestStorage.clear();
    if (!mounted) return;
    setState(() {
      _unlocked = false;
      _isMainAdmin = false;
      _currentUser = '';
      _needsSetup = true;
    });
    _snack('Admin-Konten zurückgesetzt.');
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final list = await FeedbackStorage.load();
    final reqs = await ResetRequestStorage.load();
    if (!mounted) return;
    setState(() {
      _entries = list;
      _resetRequests = reqs;
      _loading = false;
    });
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
    _snack('Zusammenfassung kopiert.');
  }

  Future<void> _openAdminManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AdminManagementScreen(),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_needsSetup) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin-Feedback', style: TextStyle(fontSize: 15)),
          centerTitle: true,
        ),
        body: StarField(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: TaqwaCard(
                  goldBorder: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Eyebrow('ERSTEINRICHTUNG', color: Colors.amber),
                      const SizedBox(height: 8),
                      Text(
                        'Haupt-Admin „$_mainAdminName“ – Passwort festlegen',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _setupPassword,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Neues Passwort',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _setupConfirm,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Passwort bestätigen',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _setup,
                        style: FilledButton.styleFrom(
                          backgroundColor: TaqwaColors.gold,
                          foregroundColor: TaqwaColors.onGold,
                        ),
                        child: const Text('Passwort speichern'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!_unlocked) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin-Feedback', style: TextStyle(fontSize: 15)),
          centerTitle: true,
        ),
        body: StarField(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: TaqwaCard(
                  goldBorder: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Eyebrow('ANMELDUNG', color: TaqwaColors.gold),
                      const SizedBox(height: 8),
                      const Text(
                        'Admin-Login',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _loginName,
                        decoration: const InputDecoration(
                          labelText: 'Admin-Name',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _loginPassword,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Passwort',
                        ),
                        onSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _login,
                        style: FilledButton.styleFrom(
                          backgroundColor: TaqwaColors.gold,
                          foregroundColor: TaqwaColors.onGold,
                        ),
                        child: const Text('Anmelden'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _forgotPassword,
                        child: const Text(
                          'Passwort vergessen?',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onLongPress: _emergencyReset,
                        child: Text(
                          'Version $appVersion · Build $appBuild',
                          style: TextStyle(
                            color: TaqwaColors.muted,
                            fontSize: 8.5,
                          ),
                        ),
                      ),
                    ],
                  ),
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
          if (_isMainAdmin)
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
                      '${_entries.length} FEEDBACK(S) · $_currentUser',
                      color: TaqwaColors.gold,
                    ),
                    const SizedBox(height: 8),
                    if (_resetRequests.isNotEmpty && _isMainAdmin) ...[
                      TaqwaCard(
                        goldBorder: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Eyebrow(
                              'PASSWORT-RESET-ANFRAGEN',
                              color: Colors.amber,
                            ),
                            const SizedBox(height: 6),
                            for (final r in _resetRequests) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () async {
                                      await ResetRequestStorage.remove(r.name);
                                      final admin = await AdminStorage.find(r.name);
                                      if (admin != null && mounted) {
                                        _snack(
                                          'Bitte Passwort für „${admin.name}“ zurücksetzen.',
                                        );
                                      }
                                      await _reload();
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: TaqwaColors.gold,
                                      foregroundColor: TaqwaColors.onGold,
                                    ),
                                    child: const Text('Freigeben'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
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

/// Verwaltungsseite für Admin-Konten (nur Haupt-Admin).
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
    final passCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neuen Admin anlegen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Admin-Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Passwort (min. 4)'),
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
            child: const Text('Anlegen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final pass = passCtrl.text;
    if (name.isEmpty || pass.length < 4) {
      _snack('Name und Passwort (min. 4) erforderlich.');
      return;
    }
    await AdminStorage.upsert(
      AdminAccount(
        name: name,
        passwordHash: hashPassword(pass),
        isMain: false,
      ),
    );
    // Benachrichtigung an den Entwickler.
    try {
      final uri = Uri.parse(
        'mailto:alsafdibaschar5@gmail.com?subject=${Uri.encodeComponent('TAQWA TRACK - Neuer Admin angelegt')}&body=${Uri.encodeComponent('Neuer Admin: $name')}',
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    await _reload();
    _snack('Admin „$name“ angelegt. Entwickler wurde benachrichtigt.');
  }

  Future<void> _resetPassword(AdminAccount admin) async {
    final passCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Passwort zurücksetzen: ${admin.name}'),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Neues Passwort (min. 4)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (passCtrl.text.length < 4) {
      _snack('Passwort muss mindestens 4 Zeichen haben.');
      return;
    }
    await AdminStorage.upsert(
      AdminAccount(
        name: admin.name,
        passwordHash: hashPassword(passCtrl.text),
        isMain: admin.isMain,
      ),
    );
    await _reload();
    _snack('Passwort für „${admin.name}“ zurückgesetzt.');
  }

  Future<void> _remove(AdminAccount admin) async {
    if (admin.isMain) {
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
                                tooltip: 'Passwort zurücksetzen',
                                onPressed: () => _resetPassword(admin),
                                icon: const Icon(Icons.key, size: 18),
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
