import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Inizializza Flutter prima di utilizzare Firebase.
  WidgetsFlutterBinding.ensureInitialized();

  // Carica la configurazione corretta per Android o iOS.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196C9),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5FAFD),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5FAFD),
          foregroundColor: Color(0xFF173B50),
          centerTitle: false,
          elevation: 0,
        ),
      ),

      // Schermata temporanea, da sostituire con il login.
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_hospital_outlined,
                size: 64,
                color: Color(0xFF2196C9),
              ),
              SizedBox(height: 16),
              Text(
                'MediCare',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF173B50),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Applicazione inizializzata',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF607D8B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
