import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/visite_viewmodel.dart';

class PrenotaVisitaScreen extends ConsumerStatefulWidget {
  const PrenotaVisitaScreen({super.key});

  @override
  ConsumerState<PrenotaVisitaScreen> createState() =>
      _PrenotaVisitaScreenState();
}

class _PrenotaVisitaScreenState
    extends ConsumerState<PrenotaVisitaScreen> {
  String? _idDottore;
  DateTime? _data;
  String? _ora;
  bool _prenotazioneInCorso = false;

  String _formattaData(DateTime data) =>
      '${data.year.toString().padLeft(4, '0')}-'
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}';

  bool _isWeekend(DateTime data) =>
      data.weekday == DateTime.saturday ||
      data.weekday == DateTime.sunday;

  DateTime _prossimoGiornoLavorativo(DateTime data) {
    var risultato = DateTime(data.year, data.month, data.day);

    while (_isWeekend(risultato)) {
      risultato = risultato.add(const Duration(days: 1));
    }

    return risultato;
  }

  Future<void> _selezionaData() async {
    final adesso = DateTime.now();
    final oggi = DateTime(adesso.year, adesso.month, adesso.day);

    final dataBase = _data == null || _data!.isBefore(oggi)
        ? oggi
        : _data!;

    final scelta = await showDatePicker(
      context: context,
      initialDate: _prossimoGiornoLavorativo(dataBase),
      firstDate: oggi,
      lastDate: DateTime(oggi.year + 1, 12, 31),
      selectableDayPredicate: (data) => !_isWeekend(data),
      helpText: 'Seleziona il giorno della visita',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
      locale: const Locale('it', 'IT'),
    );

    if (scelta != null && mounted) {
      setState(() {
        _data = scelta;
        _ora = null;
      });
    }
  }

  Future<void> _prenota() async {
    if (_idDottore == null || _data == null || _ora == null) {
      return;
    }

    setState(() => _prenotazioneInCorso = true);

    final idDottore = _idDottore!;
    final data = _formattaData(_data!);
    final ora = _ora!;

    try {
      await ref.read(visiteRepositoryProvider).prenotaVisita(
            idDottore: idDottore,
            data: data,
            ora: ora,
          );

      // Aggiorna la lista delle visite del paziente.
      ref.invalidate(visitePazienteProvider);

      // Aggiorna gli orari per il medico e la data scelti.
      ref.invalidate(
        orariDisponibiliProvider((
          dottore: idDottore,
          data: data,
        )),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visita prenotata con successo.'),
        ),
      );

      Navigator.pop(context, true);
    } catch (errore) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errore.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _prenotazioneInCorso = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dottori = ref.watch(dottoriProvider);

    final data = _data == null ? null : _formattaData(_data!);

    final orari = _idDottore != null && data != null
        ? ref.watch(
            orariDisponibiliProvider((
              dottore: _idDottore!,
              data: data,
            )),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prenota una visita'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Scegli il medico',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF17324D),
                ),
              ),
              const SizedBox(height: 12),
              dottori.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (_, _) => const Text(
                  'Impossibile caricare i medici.',
                ),
                data: (lista) {
                  if (lista.isEmpty) {
                    return const Text(
                      'Non sono presenti medici disponibili.',
                    );
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: _idDottore,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Medico',
                      border: OutlineInputBorder(),
                    ),
                    items: lista.map((dottore) {
                      final nome =
                          '${dottore['nome'] ?? ''} '
                          '${dottore['cognome'] ?? ''}'.trim();

                      return DropdownMenuItem<String>(
                        value: dottore['uid'] as String,
                        child: Text(
                          nome.isEmpty ? 'Medico' : nome,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (valore) {
                      setState(() {
                        _idDottore = valore;
                        _ora = null;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Scegli la data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF17324D),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _selezionaData,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  _data == null
                      ? 'Seleziona data'
                      : '${_data!.day.toString().padLeft(2, '0')}/'
                          '${_data!.month.toString().padLeft(2, '0')}/'
                          '${_data!.year}',
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Orari disponibili',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF17324D),
                ),
              ),
              const SizedBox(height: 12),
              if (_idDottore == null || _data == null)
                const Text('Seleziona prima il medico e la data.')
              else
                orari!.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (_, _) => const Text(
                    'Impossibile caricare gli orari.',
                  ),
                  data: (lista) {
                    if (lista.isEmpty) {
                      return const Text(
                        'Non ci sono orari disponibili per questa data.',
                      );
                    }

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: lista.map((ora) {
                        return ChoiceChip(
                          label: Text(ora),
                          selected: _ora == ora,
                          onSelected: (selezionato) {
                            setState(() {
                              _ora = selezionato ? ora : null;
                            });
                          },
                          selectedColor: const Color(0xFFBBDEFB),
                        );
                      }).toList(),
                    );
                  },
                ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _prenotazioneInCorso ||
                          _idDottore == null ||
                          _data == null ||
                          _ora == null
                      ? null
                      : _prenota,
                  child: _prenotazioneInCorso
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Conferma prenotazione'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}