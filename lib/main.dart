import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_controller.dart';
import 'data/taqwa_repository.dart';
import 'language.dart';
import 'notifications.dart';
import 'screens.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeAppDateFormats();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final controller = TaqwaController(TaqwaRepository());
  await controller.initialize();
  await NotificationService.initialize();
  runApp(TaqwaTrackApp(controller: controller));
}

class TaqwaTrackApp extends StatefulWidget {
  const TaqwaTrackApp({super.key, required this.controller});
  final TaqwaController controller;

  @override
  State<TaqwaTrackApp> createState() => _TaqwaTrackAppState();
}

class _TaqwaTrackAppState extends State<TaqwaTrackApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final language = languageFor(controller.settings?.language);
      return MaterialApp(
        title: 'TAQWA TRACK',
        debugShowCheckedModeBanner: false,
        theme: taqwaTheme(oled: controller.settings?.oled ?? false),
        locale: language.locale,
        supportedLocales: [for (final item in appLanguages) item.locale],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MainShell(controller: controller),
      );
    },
  );
}
