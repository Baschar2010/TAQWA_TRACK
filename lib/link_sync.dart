/// Wählt die passende Kopplungs-Implementierung.
///
/// Auf Android und iOS läuft die direkte UDP-Kopplung im WLAN. Im Browser
/// gibt es kein UDP; dort läuft die Kopplung vollständig über die Cloud.
library;

export 'link_sync_base.dart';
export 'link_sync_stub.dart' if (dart.library.io) 'link_sync_io.dart';
