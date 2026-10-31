import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_controller.dart';
import 'data/taqwa_repository.dart';
import 'screens.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE');
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final controller = TaqwaController(TaqwaRepository());
  await controller.initialize();
  runApp(TaqwaTrackApp(controller: controller));
}

class TaqwaTrackApp extends StatelessWidget {
  const TaqwaTrackApp({super.key, required this.controller});
  final TaqwaController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TAQWA TRACK',
    debugShowCheckedModeBanner: false,
    theme: taqwaTheme(),
    home: MainShell(controller: controller),
  );
}
