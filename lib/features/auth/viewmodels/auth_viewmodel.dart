
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/auth_repository.dart';

// Rende il repository disponibile nell'app tramite Riverpod.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// Gestisce lo stato delle operazioni di autenticazione.
final authViewModelProvider =
    AsyncNotifierProvider<AuthViewModel, void>(AuthViewModel.new);

class AuthViewModel extends AsyncNotifier<void> {
  late final AuthRepository _repository;

  @override
  Future<void> build() async {
    _repository = ref.read(authRepositoryProvider);
  }

  // Accesso tramite username e password.
  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _repository.login(
        username: username,
        password: password,
      );
    });
  }

  // Registrazione completa del paziente.
  Future<void> registerPatient({
    required String username,
    required String password,
    required String codiceFiscale,
    required String nome,
    required String cognome,
    required String dataNascita,
    required String email,
    required String telefono,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _repository.registerPatient(
        username: username,
        password: password,
        codiceFiscale: codiceFiscale,
        nome: nome,
        cognome: cognome,
        dataNascita: dataNascita,
        email: email,
        telefono: telefono,
      );
    });
  }

  // Termina la sessione Firebase.
  Future<void> logout() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _repository.logout();
    });
  }
}


final profiloPazienteProvider =
    FutureProvider<Map<String, dynamic>>((ref) {
  return ref.read(authRepositoryProvider).getProfiloPaziente();
});
