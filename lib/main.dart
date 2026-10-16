
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'navigation/app_router.dart';

Future<void> main() async {
  // Inizializza Flutter prima di utilizzare Firebase.
  WidgetsFlutterBinding.ensureInitialized();

  // Connette l'app al progetto Firebase configurato.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Rende Riverpod disponibile in tutta l'applicazione.
  runApp(
    const ProviderScope(
      child: MediCare(),
    ),
  );
}

class MediCare extends StatelessWidget {
  const MediCare({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediCare',
      debugShowCheckedModeBanner: false,

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
        supportedLocales: const [
          Locale('it', 'IT'),
          Locale('en', 'US'),
        ],
      // Tema grafico condiviso da tutte le schermate.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F9FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F9FC),
          foregroundColor: Color(0xFF17324D),
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFD9E5EE),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF2196F3),
              width: 1.5,
            ),
          ),
        ),
      ),

      // Decide quale schermata mostrare in base alla sessione
      // Firebase e al ruolo salvato in Firestore.
      home: const AppRouter(),
    );
  }
}
