import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:trackwell/firebase_options.dart';
import 'package:trackwell/app_theme.dart';
import 'package:trackwell/login_screen.dart';
import 'package:trackwell/signup_screen.dart';
import 'package:trackwell/dashboard_screen.dart';
import 'package:trackwell/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // küçük modern kullanım

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrackWell',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,

      initialRoute: '/login',

      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const DashboardScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}