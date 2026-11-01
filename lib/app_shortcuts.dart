import 'package:flutter/services.dart';

/// Ziele, die über einen Long-Press auf das App-Icon erreichbar sind.
enum AppShortcut { quran, prayer, family }

/// Liest die Kennung aus dem Android-Intent.
AppShortcut? shortcutFromId(String? id) => switch (id) {
  'quran' => AppShortcut.quran,
  'prayer' => AppShortcut.prayer,
  'family' => AppShortcut.family,
  _ => null,
};

/// Brücke zwischen Android-Schnellstartaktionen und Flutter.
///
/// Der native Teil schickt beim Start die gewählte Aktion und meldet später
/// eintreffende Aktionen über denselben Kanal.
class AppShortcutService {
  AppShortcutService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'taqwa_track/shortcuts';

  final MethodChannel _channel;

  /// Aktion, mit der die App gestartet wurde (falls vorhanden).
  Future<AppShortcut?> initialShortcut() async {
    try {
      final id = await _channel.invokeMethod<String>('getInitialShortcut');
      return shortcutFromId(id);
    } catch (_) {
      return null;
    }
  }

  /// Horcht auf Aktionen, während die App bereits läuft.
  void listen(ValueChanged<AppShortcut> onShortcut) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'shortcut') return null;
      final shortcut = shortcutFromId(call.arguments as String?);
      if (shortcut != null) onShortcut(shortcut);
      return null;
    });
  }

  void dispose() {
    try {
      _channel.setMethodCallHandler(null);
    } catch (_) {
      // Kanal existiert in Tests nicht – ignorieren.
    }
  }
}
