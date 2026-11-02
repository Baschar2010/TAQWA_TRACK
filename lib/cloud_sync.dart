import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'domain.dart';

/// Verbindungszustand der Cloud-Synchronisation.
enum CloudState { idle, online, offline }

/// Ergebnis eines Abrufs aus dem Cloud-Kanal.
class CloudFetch {
  const CloudFetch({this.envelopes = const [], this.cursor});

  /// Neu eingetroffene Nachrichten, älteste zuerst.
  final List<CloudEnvelope> envelopes;

  /// Kennung der zuletzt gesehenen Nachricht. Sie wird lokal gespeichert,
  /// damit nach einem Neustart nichts doppelt ankommt.
  final String? cursor;
}

/// Eine Nachricht, die über den Cloud-Kanal läuft. Sie ist absichtlich
/// unabhängig vom Transport, damit später ein anderer Anbieter (Firebase,
/// Supabase, eigener Server) nur den [CloudRelay] austauschen muss.
class CloudEnvelope {
  const CloudEnvelope({
    required this.type,
    required this.fromCode,
    required this.fromName,
    this.kind,
    this.prayer,
    this.text,
    this.sentAt,
    this.snapshot,
  });

  static const int version = 1;

  /// `hello` (Kopplung), `ping` (Nudge oder Nachricht) oder `status`.
  final String type;
  final String fromCode;
  final String fromName;
  final String? kind;
  final String? prayer;
  final String? text;
  final String? sentAt;
  final ProfileSnapshot? snapshot;

  factory CloudEnvelope.hello(ProfileSnapshot snapshot) => CloudEnvelope(
    type: 'hello',
    fromCode: snapshot.code,
    fromName: snapshot.name,
    snapshot: snapshot,
  );

  factory CloudEnvelope.status(ProfileSnapshot snapshot) => CloudEnvelope(
    type: 'status',
    fromCode: snapshot.code,
    fromName: snapshot.name,
    snapshot: snapshot,
  );

  factory CloudEnvelope.ping(FamilyPing ping) => CloudEnvelope(
    type: 'ping',
    fromCode: ping.fromCode,
    fromName: ping.fromName,
    kind: ping.kind.name,
    prayer: ping.prayer?.name,
    text: ping.text,
    sentAt: ping.sentAt,
  );

  /// Wandelt eine Gebets-Erinnerung oder Nachricht zurück.
  FamilyPing? toPing() {
    final parsedKind = FamilyPingKind.values.asNameMap()[kind ?? ''];
    if (parsedKind == null) return null;
    return FamilyPing(
      fromCode: fromCode,
      fromName: fromName,
      kind: parsedKind,
      prayer: Prayer.values.asNameMap()[prayer ?? ''],
      text: text ?? '',
      sentAt: sentAt,
    );
  }

  Map<String, Object?> toJson() => {
    'v': version,
    't': type,
    'from': fromCode,
    'name': fromName,
    if (kind != null) 'k': kind,
    if (prayer != null) 'p': prayer,
    if (text != null) 'x': text,
    if (sentAt != null) 'at': sentAt,
    if (snapshot != null)
      'snap': base64UrlEncode(
        utf8.encode(snapshot!.encode()),
      ).replaceAll('=', ''),
  };

  String encode() => jsonEncode(toJson());

  /// Liest eine Cloud-Nachricht. Ungültige Inhalte ergeben `null`.
  static CloudEnvelope? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final type = decoded['t'];
      final from = decoded['from'];
      if (type is! String || from is! String || from.trim().isEmpty) {
        return null;
      }
      if (type != 'hello' && type != 'ping' && type != 'status') return null;

      ProfileSnapshot? snapshot;
      final snap = decoded['snap'];
      if (snap is String && snap.isNotEmpty) {
        snapshot = ProfileSnapshot.tryParse(
          utf8.decode(base64Url.decode(base64Url.normalize(snap))),
        );
        // Der Schnappschuss muss zum Absender gehören.
        if (snapshot == null || snapshot.code != from) return null;
      }
      // Ein Status ohne Fortschritt ist wertlos.
      if (type == 'status' && snapshot == null) return null;

      final name = decoded['name'];
      return CloudEnvelope(
        type: type,
        fromCode: from.trim(),
        fromName: name is String ? name : '',
        kind: decoded['k'] is String ? decoded['k'] as String : null,
        prayer: decoded['p'] is String ? decoded['p'] as String : null,
        text: decoded['x'] is String ? decoded['x'] as String : null,
        sentAt: decoded['at'] is String ? decoded['at'] as String : null,
        snapshot: snapshot,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Leitet den geheimen Kanalnamen aus dem Kopplungsschlüssel ab.
///
/// Der Schlüssel selbst verlässt das Gerät nur im QR-Code und in der
/// Kopplungsnachricht. Der Kanalname ist ein SHA-256-Abdruck davon und
/// verrät den Schlüssel nicht.
String? cloudTopicFor(String inboxKey) {
  final clean = inboxKey.trim();
  if (clean.length < 16) return null;
  final digest = sha256.convert(utf8.encode(clean)).bytes;
  final encoded = base64UrlEncode(digest).replaceAll('=', '');
  return 'taqwa_${encoded.substring(0, 32)}';
}

/// Transport für den Cloud-Kanal.
abstract class CloudRelay {
  /// Veröffentlicht eine Nachricht im Postfach des Empfängers.
  Future<bool> publish({
    required String inboxKey,
    required CloudEnvelope envelope,
  });

  /// Holt alle Nachrichten, die seit [cursor] eingetroffen sind.
  Future<CloudFetch> fetch({required String inboxKey, String? cursor});

  void close();
}

/// Kostenloser Cloud-Kanal ohne Konto und ohne Firebase-Projekt.
///
/// Der Dienst [ntfy.sh] ist ein offener, gemeinnützig betriebener
/// Nachrichten-Relay. Jedes Postfach ist ein zufälliger, nicht erratbarer
/// Kanalname; die App legt ihn aus dem Kopplungsschlüssel ab. Damit
/// funktioniert der Austausch über WLAN, mobile Daten und im Ausland –
/// ohne Serverkosten und ohne Anmeldung.
///
/// Wer später Firebase oder Supabase einsetzen möchte, implementiert einfach
/// diese vier Methoden neu und reicht die Klasse an den Controller weiter.
class NtfyCloudRelay implements CloudRelay {
  NtfyCloudRelay({
    this.endpoint = 'https://ntfy.sh',
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  final String endpoint;
  final Duration timeout;
  final http.Client _client;

  Uri _topicUri(String topic, {Map<String, String>? query}) =>
      Uri.parse('$endpoint/$topic').replace(queryParameters: query);

  @override
  Future<bool> publish({
    required String inboxKey,
    required CloudEnvelope envelope,
  }) async {
    final topic = cloudTopicFor(inboxKey);
    if (topic == null) return false;
    try {
      final response = await _client
          .post(
            _topicUri(''),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'topic': topic,
              'message': envelope.encode(),
              'priority': 4,
              'tags': ['taqwa_track'],
            }),
          )
          .timeout(timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (error) {
      debugPrint('Cloud-Nachricht konnte nicht gesendet werden: $error');
      return false;
    }
  }

  @override
  Future<CloudFetch> fetch({required String inboxKey, String? cursor}) async {
    final topic = cloudTopicFor(inboxKey);
    if (topic == null) return const CloudFetch();
    final uri = _topicUri(
      '$topic/json',
      query: {
        'poll': '1',
        'since': (cursor == null || cursor.isEmpty) ? 'all' : cursor,
      },
    );
    final response = await _client.get(uri).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const CloudUnavailable();
    }
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    final envelopes = <CloudEnvelope>[];
    var next = cursor;
    for (final line in const LineSplitter().convert(body)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final Object? decoded;
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        continue;
      }
      if (decoded is! Map) continue;
      final id = decoded['id'];
      if (id is String && id.isNotEmpty) next = id;
      if (decoded['event'] != 'message') continue;
      final message = decoded['message'];
      if (message is! String) continue;
      final envelope = CloudEnvelope.tryParse(message);
      if (envelope != null) envelopes.add(envelope);
    }
    return CloudFetch(envelopes: envelopes, cursor: next);
  }

  @override
  void close() => _client.close();
}

/// Der Cloud-Kanal war gerade nicht erreichbar (z. B. kein Netz).
class CloudUnavailable implements Exception {
  const CloudUnavailable();

  @override
  String toString() => 'CloudUnavailable';
}
