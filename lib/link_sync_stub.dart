import 'domain.dart';

export 'link_sync_base.dart';

/// Kopplung im Browser: Es gibt kein UDP. Die Verbindung läuft dort
/// vollständig über den Cloud-Kanal (QR-Code + ntfy.sh).
class LinkSyncService {
  LinkSyncService({this.allowDesktop = false, int? port})
    : port = port ?? defaultPort;

  static const int defaultPort = 48765;
  static const String packetPrefix = 'TTLINK1';

  final bool allowDesktop;
  final int port;

  String? get host => null;
  bool get active => false;

  Future<void> start({
    required Future<ProfileSnapshot> Function() mySnapshot,
    required Future<void> Function(ProfileSnapshot) onPeerLinked,
    Future<void> Function(FamilyPing)? onMessage,
  }) async {}

  Future<bool> refreshHost() async => false;

  Future<bool> handshake({
    required ProfileSnapshot peer,
    required ProfileSnapshot mine,
    Duration timeout = const Duration(seconds: 3),
  }) async => false;

  bool sendPing({
    required String host,
    required int port,
    required FamilyPing ping,
  }) => false;

  void stop() {}

  static Future<String?> detectLocalIpv4() async => null;
}
