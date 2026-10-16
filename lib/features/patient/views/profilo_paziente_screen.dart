
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/viewmodels/auth_viewmodel.dart';

class ProfiloPazienteScreen extends ConsumerWidget {
  const ProfiloPazienteScreen({super.key});

  static const _blu = Color(0xFF2196F3);
  static const _bluScuro = Color(0xFF17324D);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilo = ref.watch(profiloPazienteProvider);

    return profilo.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (errore, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Impossibile caricare il profilo: $errore',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (dati) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person_outline,
                    size: 42,
                    color: _blu,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Il mio profilo',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: _bluScuro,
                  ),
                ),
                SizedBox(height: 4),
                Text('Gestisci i tuoi dati personali'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _campo('Nome', dati['nome']),
          _campo('Cognome', dati['cognome']),
          _campo('Username', dati['username']),
          _campo('Codice fiscale', dati['codiceFiscale']),
          _campo('Data di nascita', dati['dataNascita']),
          _campo('Email', dati['email']),
          _campo('Telefono', dati['telefono']),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: () => _modificaProfilo(context, ref, dati),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifica dati personali'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo(String titolo, dynamic valore) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD9E5EE)),
      ),
      child: ListTile(
        title: Text(
          titolo,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF607D8B),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            valore?.toString().isNotEmpty == true
                ? valore.toString()
                : 'Non disponibile',
            style: const TextStyle(
              fontSize: 16,
              color: _bluScuro,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _modificaProfilo(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> dati,
  ) async {
    final risultato = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _ModificaProfiloDialog(dati: dati),
    );

    if (risultato == null) return;

    try {
      await ref.read(authRepositoryProvider).aggiornaProfiloPaziente(
            nome: risultato['nome']!,
            cognome: risultato['cognome']!,
            email: risultato['email']!,
            telefono: risultato['telefono']!,
          );

      ref.invalidate(profiloPazienteProvider);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profilo aggiornato correttamente.'),
        ),
      );
    } catch (errore) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errore.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _ModificaProfiloDialog extends StatefulWidget {
  const _ModificaProfiloDialog({required this.dati});

  final Map<String, dynamic> dati;

  @override
  State<_ModificaProfiloDialog> createState() =>
      _ModificaProfiloDialogState();
}

class _ModificaProfiloDialogState extends State<_ModificaProfiloDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _cognome;
  late final TextEditingController _email;
  late final TextEditingController _telefono;

  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: widget.dati['nome']?.toString());
    _cognome =
        TextEditingController(text: widget.dati['cognome']?.toString());
    _email = TextEditingController(text: widget.dati['email']?.toString());
    _telefono =
        TextEditingController(text: widget.dati['telefono']?.toString());
  }

  @override
  void dispose() {
    _nome.dispose();
    _cognome.dispose();
    _email.dispose();
    _telefono.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifica profilo'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _input(_nome, 'Nome'),
              _input(_cognome, 'Cognome'),
              _input(
                _email,
                'Email',
                tipo: TextInputType.emailAddress,
                validazione: (valore) {
                  if (valore == null || !valore.contains('@')) {
                    return 'Inserisci un’email valida';
                  }
                  return null;
                },
              ),
              _input(
                _telefono,
                'Telefono',
                tipo: TextInputType.phone,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;

            Navigator.pop(context, {
              'nome': _nome.text.trim(),
              'cognome': _cognome.text.trim(),
              'email': _email.text.trim(),
              'telefono': _telefono.text.trim(),
            });
          },
          child: const Text('Salva'),
        ),
      ],
    );
  }

  Widget _input(
    TextEditingController controller,
    String etichetta, {
    TextInputType? tipo,
    String? Function(String?)? validazione,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: tipo,
        validator: (valore) {
          if (valore == null || valore.trim().isEmpty) {
            return 'Campo obbligatorio';
          }
          return validazione?.call(valore);
        },
        decoration: InputDecoration(
          labelText: etichetta,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
