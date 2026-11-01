import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_controller.dart';
import 'app_shortcuts.dart';
import 'data/taqwa_repository.dart';
import 'language.dart';
import 'notifications.dart';
import 'screens.dart';
import 'theme.dart';
import 'update_dialog.dart';
import 'update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeAppDateFormats();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final controller = TaqwaController(TaqwaRepository());
  await controller.initialize();
  await NotificationService.initialize();
  runApp(
    TaqwaTrackApp(
      controller: controller,
      updateService: UpdateService(),
      shortcuts: AppShortcutService(),
    ),
  );
}

/// Wandelt den gespeicherten Wert in einen [ThemeMode] um.
ThemeMode themeModeFrom(String? value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

class TaqwaTrackApp extends StatefulWidget {
  const TaqwaTrackApp({
    super.key,
    required this.controller,
    this.updateService,
    this.shortcuts,
  });
  final TaqwaController controller;

  /// Wird von [main] gesetzt. In Tests bleibt der Wert `null`, damit keine
  /// echten Netzwerkaufrufe und Timer entstehen.
  final UpdateService? updateService;

  /// Verbindung zu den Android-Schnellstartaktionen. In Tests `null`.
  final AppShortcutService? shortcuts;

  @override
  State<TaqwaTrackApp> createState() => _TaqwaTrackAppState();
}

class _TaqwaTrackAppState extends State<TaqwaTrackApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _maybeCheckForUpdates();
  }

  /// Einmaliger Update-Check kurz nach dem Start. Fehler und Offline-Zustand
  /// bleiben unsichtbar – die App funktioniert immer vollständig.
  Future<void> _maybeCheckForUpdates() async {
    final service = widget.updateService;
    if (service == null || _updateChecked) return;
    _updateChecked = true;
    // Erst den ersten Frame zeichnen lassen, dann prüfen.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final release = await service.check();
    if (!mounted || release == null) return;
    final navContext =
        _navigatorKey.currentState?.overlay?.context ??
        _navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;
    await showUpdateDialog(
      navContext,
      release: release,
      currentVersion: service.currentVersion,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Nach einem WLAN-Wechsel ändert sich die lokale IP. Der QR-Code muss
    // dann mit der neuen Adresse erzeugt werden.
    if (state == AppLifecycleState.resumed) {
      widget.controller.refreshLinkSync();
    }
  }

  @override
  void didChangePlatformBrightness() {
    // Im Modus "System" muss die Palette neu gewählt werden.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final language = languageFor(controller.settings?.language);
      final mode = themeModeFrom(controller.settings?.themeMode);
      final brightness = switch (mode) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        ThemeMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
      };
      final theme = taqwaTheme(
        oled: controller.settings?.oled ?? false,
        brightness: brightness,
      );
      return MaterialApp(
        title: 'TAQWA TRACK',
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: theme,
        themeMode: brightness == Brightness.light
            ? ThemeMode.light
            : ThemeMode.dark,
        locale: language.locale,
        supportedLocales: [for (final item in appLanguages) item.locale],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MainShell(controller: controller, shortcuts: widget.shortcuts),
      );
    },
  );
}
