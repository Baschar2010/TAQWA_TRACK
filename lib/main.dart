import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_controller.dart';
import 'data/taqwa_repository.dart';
import 'language.dart';
import 'notifications.dart';
import 'screens.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE');
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final controller = TaqwaController(TaqwaRepository());
  await controller.initialize();
  await NotificationService.initialize();
  runApp(TaqwaTrackApp(controller: controller));
}

class TaqwaTrackApp extends StatelessWidget {
  const TaqwaTrackApp({super.key, required this.controller});
  final TaqwaController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
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
