import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'screens/scheme_screen.dart';

void main() {
  runApp(const ElectricalSchemeApp());
}

class ElectricalSchemeApp extends StatelessWidget {
  const ElectricalSchemeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мнемосхема',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
        // textTheme:
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/scheme': (context) => const SchemeScreen(),
        // '/': (context) => const SchemeScreen(),
        // '/scheme': (context) => const SchemeScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
