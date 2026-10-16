
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/patient/views/home_paziente_screen.dart';

import '../features/auth/viewmodels/auth_viewmodel.dart';

import '../features/doctor/views/home_dottore_screen.dart';

import '../features/auth/views/login_screen.dart';
// import '../data/repositories/auth_repository.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final userRoleProvider = FutureProvider.family<String?, String>((ref, uid) {
  return ref.read(authRepositoryProvider).getUserRole(uid);
});

class AppRouter extends ConsumerWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _LoadingScreen(),
      error: (_, _) => const LoginScreen(),
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }

        final roleState = ref.watch(userRoleProvider(user.uid));

        return roleState.when(
          loading: () => const _LoadingScreen(),
          error: (_, _) => const _ErrorScreen(),
          data: (role) {
            switch (role) {
              case 'paziente':
                return const HomePazienteScreen();
              case 'dottore':
                return const HomeDottoreScreen();
              default:
                return const _ErrorScreen();
            }
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Impossibile caricare il profilo. Riprova più tardi.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
