
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/landing_page.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MzaziCareApp());
}

class MzaziCareApp extends StatelessWidget {
  const MzaziCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, child) {
        return MaterialApp(
          title: 'MzaziCare',
          debugShowCheckedModeBanner: false,
          theme: MzaziCareTheme.light,
          darkTheme: MzaziCareTheme.dark,
          themeMode: ThemeController.instance.themeMode,
          home: const LandingPage(),
        );
      },
    );
  }
}
