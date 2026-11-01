import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'domain.dart';

/// Ergebnis einer Kopplung.
class LinkResult {
  const LinkResult({this.snapshot, this.mutual = false, this.reason});

  /// Der gescannte Partner, oder `null`, wenn der Code nicht gelesen wurde.
  final ProfileSnapshot? snapshot;

  /// `true`, wenn das Gegenüber im selben Moment ebenfalls verknüpft wurde.
  final bool mutual;

  /// Zusätzlicher Hinweis, falls die Gegenseite nicht erreichbar war.
  final String? reason;

  bool get linked => snapshot != null;
}

/// Direkte Geräte-zu-Geräte-Kopplung über das lokale WLAN.
///
/// Beim Scannen eines QR-Codes schickt das scannende Gerät seinen eigenen
/// Schnappschuss per UDP an das andere Gerät. Dieses speichert den Partner
/// sofort und antwortet mit seinem aktuellen Schnappschuss. Damit sind beide
/// Seiten mit einem einzigen Scan gegenseitig verknüpft – ohne Server und
/// ohne Internet.
class LinkSyncService {
  LinkSyncService({this.allowDesktop = false, int? port})
    : port = port ?? defaultPort;

  static const int defaultPort = 48765;
  static const String packetPrefix = 'TTLINK1';

  final bool allowDesktop;
  final int port;

  RawDatagramSocket? _socket;
  String? _host;
  final Map<String, Completer<ProfileSnapshot>> _pending = {};

  String? get host => _host;
  bool get active => _socket != null;

  bool get _supported =>
      allowDesktop || (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  /// Startet den lokalen Empfang und ermittelt die eigene IP-Adresse.
  Future<void> start({
    required Future<ProfileSnapshot> Function() mySnapshot,
    required Future<void> Function(ProfileSnapshot) onPeerLinked,
  }) async {
    if (!_supported || _socket != null) return;
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
      );
      _socket = socket;
      _host = await detectLocalIpv4();
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        unawaited(_handle(datagram, mySnapshot, onPeerLinked));
      });
    } catch (error) {
      debugPrint('Lokale Kopplung nicht verfügbar: $error');
      _socket = null;
      _host = null;
    }
  }

  /// Prüft erneut die lokale IP (z. B. nach einem WLAN-Wechsel).
  /// Gibt `true` zurück, wenn sich die Adresse geändert hat.
  Future<bool> refreshHost() async {
    if (_socket == null) return false;
    final next = await detectLocalIpv4();
    if (next != null && next != _host) {
      _host = next;
      return true;
    }
    return false;
  }

  /// Sendet den eigenen Stand an das gescannte Gerät und wartet kurz auf
  /// dessen Antwort. Gibt `true` zurück, wenn die Gegenseite geantwortet hat.
  Future<bool> handshake({
    required ProfileSnapshot peer,
    required ProfileSnapshot mine,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final socket = _socket;
    final targetHost = peer.syncHost;
    if (socket == null || targetHost == null) return false;
    final address = InternetAddress.tryParse(targetHost);
    if (address == null) return false;

    final completer = Completer<ProfileSnapshot>();
    _pending[peer.code] = completer;
    try {
      _send(socket, 'HELLO', mine, address, peer.syncPort ?? port);
      await completer.future.timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    } catch (error) {
      debugPrint('Kopplung fehlgeschlagen: $error');
      return false;
    } finally {
      _pending.remove(peer.code);
    }
  }

  Future<void> _handle(
    Datagram datagram,
    Future<ProfileSnapshot> Function() mySnapshot,
    Future<void> Function(ProfileSnapshot) onPeerLinked,
  ) async {
    try {
      final text = utf8.decode(datagram.data, allowMalformed: true);
      final parts = text.split('|');
      if (parts.length != 3 || parts[0] != packetPrefix) return;
      final snapshot = ProfileSnapshot.tryParse(
        utf8.decode(base64Decode(parts[2])),
      );
      if (snapshot == null) return;
      if (parts[1] == 'HELLO') {
        await onPeerLinked(snapshot);
        final socket = _socket;
        if (socket == null) return;
        _send(
          socket,
          'WELCOME',
          await mySnapshot(),
          datagram.address,
          datagram.port,
        );
      } else if (parts[1] == 'WELCOME') {
        await onPeerLinked(snapshot);
        _pending[snapshot.code]?.complete(snapshot);
      }
    } catch (error) {
      debugPrint('Kopplungsnachricht konnte nicht gelesen werden: $error');
    }
  }

  void _send(
    RawDatagramSocket socket,
    String kind,
    ProfileSnapshot snapshot,
    InternetAddress address,
    int targetPort,
  ) {
    final encoded = base64Encode(utf8.encode(snapshot.encode()));
    socket.send(
      utf8.encode('$packetPrefix|$kind|$encoded'),
      address,
      targetPort,
    );
  }

  void stop() {
    _pending.clear();
    _socket?.close();
    _socket = null;
    _host = null;
  }

  /// Ermittelt die erste private IPv4-Adresse des Geräts.
  static Future<String?> detectLocalIpv4() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      final addresses = [
        for (final interface in interfaces)
          for (final address in interface.addresses) address.address,
      ];
      bool isPrivate(String ip) =>
          ip.startsWith('192.168.') ||
          ip.startsWith('10.') ||
          RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip);
      for (final ip in addresses) {
        if (isPrivate(ip)) return ip;
      }
      for (final ip in addresses) {
        if (ip != '127.0.0.1' && !ip.startsWith('169.254.')) return ip;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
