
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/auth_viewmodel.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _username = TextEditingController();
  final _password = TextEditingController();
  final _codiceFiscale = TextEditingController();
  final _nome = TextEditingController();
  final _cognome = TextEditingController();
  final _dataNascita = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();

  bool _passwordVisible = false;
  DateTime? _dataSelezionata;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _codiceFiscale.dispose();
    _nome.dispose();
    _cognome.dispose();
    _dataNascita.dispose();
    _email.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _selezionaData() async {
    final oggi = DateTime.now();

    final data = await showDatePicker(
      context: context,
      initialDate: DateTime(oggi.year - 18, oggi.month, oggi.day),
      firstDate: DateTime(1900),
      lastDate: oggi,
      helpText: 'Seleziona la data di nascita',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
      locale: const Locale('it', 'IT'),
    );

    if (data != null) {
      setState(() {
        _dataSelezionata = data;
        _dataNascita.text =
            '${data.day.toString().padLeft(2, '0')}/'
            '${data.month.toString().padLeft(2, '0')}/'
            '${data.year}';
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authViewModelProvider.notifier).registerPatient(
          username: _username.text.trim(),
          password: _password.text,
          codiceFiscale: _codiceFiscale.text.trim(),
          nome: _nome.text.trim(),
          cognome: _cognome.text.trim(),
          dataNascita: _dataNascita.text,
          email: _email.text.trim(),
          telefono: _telefono.text.trim(),
        );

    if (!mounted) return;

    final authState = ref.read(authViewModelProvider);

    authState.whenOrNull(
      error: (error, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_messaggioErrore(error)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      },
      data: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registrazione completata!'),
          ),
        );

        // Firebase ha autenticato il nuovo utente.
        // AppRouter gestirà la schermata successiva.
        Navigator.pop(context);
      },
    );
  }

  String _messaggioErrore(Object error) {
    final messaggio = error.toString();

    if (messaggio.contains('email-already-in-use')) {
      return 'Questo username è già registrato.';
    }
    if (messaggio.contains('invalid-email')) {
      return 'Username non valido.';
    }
    if (messaggio.contains('weak-password')) {
      return 'La password deve contenere almeno 6 caratteri.';
    }
    if (messaggio.contains('permission-denied')) {
      return 'Non è stato possibile salvare il profilo.';
    }

    return 'Registrazione non riuscita. Riprova.';
  }

  InputDecoration _decorazione(String label, IconData icona) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icona),
      border: const OutlineInputBorder(),
    );
  }

  String? _campoObbligatorio(String? valore, String nomeCampo) {
    if (valore == null || valore.trim().isEmpty) {
      return 'Inserisci $nomeCampo.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authViewModelProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrazione'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.person_add_alt_1,
                      size: 60,
                      color: Color(0xFF2196F3),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Crea il tuo account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF17324D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Inserisci i tuoi dati personali per registrarti.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF607D8B)),
                    ),
                    const SizedBox(height: 28),

                    // Username utilizzato per accedere all'app.
                    TextFormField(
                      controller: _username,
                      decoration: _decorazione(
                        'Username',
                        Icons.account_circle_outlined,
                      ),
                      validator: (value) {
                        final errore =
                            _campoObbligatorio(value, 'lo username');
                        if (errore != null) return errore;

                        if (value!.trim().contains('@')) {
                          return 'Lo username non deve contenere @.';
                        }
                        if (value.trim().length < 3) {
                          return 'Usa almeno 3 caratteri.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Firebase.
                    TextFormField(
                      controller: _password,
                      obscureText: !_passwordVisible,
                      decoration: _decorazione(
                        'Password',
                        Icons.lock_outline,
                      ).copyWith(
                        suffixIcon: IconButton(
                          tooltip: _passwordVisible
                              ? 'Nascondi password'
                              : 'Mostra password',
                          onPressed: () {
                            setState(() {
                              _passwordVisible = !_passwordVisible;
                            });
                          },
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Inserisci la password.';
                        }
                        if (value.length < 6) {
                          return 'Usa almeno 6 caratteri.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _codiceFiscale,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 16,
                      decoration: _decorazione(
                        'Codice fiscale',
                        Icons.badge_outlined,
                      ).copyWith(counterText: ''),
                      validator: (value) {
                        final errore =
                            _campoObbligatorio(value, 'il codice fiscale');
                        if (errore != null) return errore;

                        if (!RegExp(
                          r'^[A-Za-z0-9]{16}$',
                        ).hasMatch(value!.trim())) {
                          return 'Inserisci un codice fiscale di 16 caratteri.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _nome,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decorazione(
                        'Nome',
                        Icons.person_outline,
                      ),
                      validator: (value) =>
                          _campoObbligatorio(value, 'il nome'),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _cognome,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decorazione(
                        'Cognome',
                        Icons.person_outline,
                      ),
                      validator: (value) =>
                          _campoObbligatorio(value, 'il cognome'),
                    ),
                    const SizedBox(height: 16),

                    // La data viene scelta dal calendario.
                    TextFormField(
                      controller: _dataNascita,
                      readOnly: true,
                      onTap: _selezionaData,
                      decoration: _decorazione(
                        'Data di nascita',
                        Icons.calendar_month_outlined,
                      ).copyWith(
                        hintText: 'GG/MM/AAAA',
                      ),
                      validator: (_) => _dataSelezionata == null
                          ? 'Seleziona la data di nascita.'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Email personale, distinta da quella tecnica Firebase.
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _decorazione(
                        'Email personale',
                        Icons.email_outlined,
                      ),
                      validator: (value) {
                        final errore =
                            _campoObbligatorio(value, 'l’email');
                        if (errore != null) return errore;

                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(value!.trim())) {
                          return 'Inserisci un indirizzo email valido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _telefono,
                      keyboardType: TextInputType.phone,
                      decoration: _decorazione(
                        'Telefono',
                        Icons.phone_outlined,
                      ),
                      validator: (value) {
                        final errore =
                            _campoObbligatorio(value, 'il numero di telefono');
                        if (errore != null) return errore;

                        if (value!.trim().length < 6) {
                          return 'Inserisci un numero valido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: isLoading ? null : _register,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Registrati',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Hai già un account? Accedi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
