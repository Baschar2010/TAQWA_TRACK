import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_info.dart';

/// GitHub-Repository, aus dem Updates und Releases geladen werden.
const githubOwner = 'Baschar2010';
const githubRepo = 'TAQWA_TRACK';

const githubLatestReleaseApi =
    'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
const githubReleasesPage =
    'https://github.com/$githubOwner/$githubRepo/releases';

/// Eine veröffentlichte Version auf GitHub.
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.tag,
    required this.apkUrl,
    required this.pageUrl,
    this.notes = '',
  });

  /// Reine Versionsnummer ohne führendes „v“ und ohne Build-Suffix.
  final String version;

  /// Ursprüngliches Tag, z. B. `v1.6.0`.
  final String tag;

  /// Direkter Download-Link zur APK (oder die Release-Seite als Fallback).
  final String apkUrl;

  /// Release-Seite im Browser.
  final String pageUrl;

  /// Änderungstext des Releases.
  final String notes;

  /// Liest ein Release aus der Antwort der GitHub-API. Ungültige Antworten
  /// ergeben `null`, damit ein kaputter Server die App nie stören kann.
  static ReleaseInfo? fromGitHub(Object? json) {
    if (json is! Map) return null;
    final tag = (json['tag_name'] as String?)?.trim();
    if (tag == null || tag.isEmpty) return null;
    final version = normalizeVersion(tag);
    if (version == null) return null;

    String? apk;
    final assets = json['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map) continue;
        final name = (asset['name'] as String?)?.toLowerCase() ?? '';
        final url = asset['browser_download_url'];
        if (name.endsWith('.apk') && url is String && url.isNotEmpty) {
          apk = url;
          break;
        }
      }
    }

    final page = switch (json['html_url']) {
      final String url when url.isNotEmpty => url,
      _ => githubReleasesPage,
    };

    return ReleaseInfo(
      version: version,
      tag: tag,
      apkUrl: apk ?? page,
      pageUrl: page,
      notes: switch (json['body']) {
        final String body => body.trim(),
        _ => '',
      },
    );
  }
}

/// Entfernt `v`-Präfix und Build-Suffix (`+9`) und prüft, ob nur Zahlen und
/// Punkte übrig bleiben. Liefert `null` für unbrauchbare Tags.
String? normalizeVersion(String tag) {
  final cleaned = tag
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split('+')
      .first
      .split('-')
      .first;
  if (cleaned.isEmpty || !RegExp(r'^\d+(\.\d+)*$').hasMatch(cleaned)) {
    return null;
  }
  return cleaned;
}

/// Vergleicht zwei Versionsnummern. Ergebnis > 0 bedeutet, dass [a] neuer ist.
int compareVersions(String a, String b) {
  List<int> parts(String value) => value
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList(growable: false);

  final left = parts(normalizeVersion(a) ?? a);
  final right = parts(normalizeVersion(b) ?? b);
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final x = i < left.length ? left[i] : 0;
    final y = i < right.length ? right[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

typedef ReleaseFetcher = Future<ReleaseInfo?> Function();

/// Prüft beim Start und auf Wunsch, ob auf GitHub eine neuere Version liegt.
class UpdateService {
  UpdateService({
    ReleaseFetcher? fetchLatest,
    String currentVersion = appVersion,
  }) : _fetchLatest = fetchLatest ?? fetchLatestRelease,
       currentVersion = normalizeVersion(currentVersion) ?? currentVersion;

  final ReleaseFetcher _fetchLatest;

  /// Installierte Version, gegen die verglichen wird.
  final String currentVersion;

  /// Liefert nur dann ein Release, wenn es wirklich neuer ist. Netzwerk-
  /// oder Serverfehler werden bewusst verschluckt: Offline ist Normalzustand.
  Future<ReleaseInfo?> check() async {
    try {
      final release = await _fetchLatest().timeout(const Duration(seconds: 8));
      if (release == null) return null;
      if (compareVersions(release.version, currentVersion) <= 0) return null;
      return release;
    } catch (_) {
      return null;
    }
  }

  /// Fragt die neueste Veröffentlichung bei GitHub ab.
  static Future<ReleaseInfo?> fetchLatestRelease() async {
    final client = http.Client();
    try {
      final response = await client
          .get(
            Uri.parse(githubLatestReleaseApi),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'TAQWA-TRACK/$appVersion',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      return ReleaseInfo.fromGitHub(jsonDecode(body));
    } finally {
      client.close();
    }
  }
}
