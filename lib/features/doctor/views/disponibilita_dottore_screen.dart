
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/dottore_viewmodel.dart';

class DisponibilitaDottoreScreen extends ConsumerStatefulWidget {
  const DisponibilitaDottoreScreen({super.key});

  @override
  ConsumerState<DisponibilitaDottoreScreen> createState() =>
      _DisponibilitaDottoreScreenState();
}

class _DisponibilitaDottoreScreenState
    extends ConsumerState<DisponibilitaDottoreScreen> {
  static const _blu = Color(0xFF2196F3);
  static const _bluScuro = Color(0xFF17324D);

  static const _orari = [
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '15:00',
    '16:00',
    '17:00',
  ];

  late DateTime _dataSelezionata;
  bool _operazioneInCorso = false;

  @override
  void initState() {
    super.initState();

    // Se l'app viene aperta nel weekend, seleziona il lunedì successivo.
    _dataSelezionata = _prossimoGiornoLavorativo(DateTime.now());
  }

  // Sabato e domenica sono sempre non disponibili.
  bool _isWeekend(DateTime data) {
    return data.weekday == DateTime.saturday ||
        data.weekday == DateTime.sunday;
  }

  // Restituisce il primo giorno lavorativo a partire dalla data indicata.
  DateTime _prossimoGiornoLavorativo(DateTime data) {
    var risultato = DateUtils.dateOnly(data);

    while (_isWeekend(risultato)) {
      risultato = risultato.add(const Duration(days: 1));
    }

    return risultato;
  }

  String get _data => _formattaData(_dataSelezionata);

  String _formattaData(DateTime data) {
    return '${data.year.toString().padLeft(4, '0')}-'
        '${data.month.toString().padLeft(2, '0')}-'
        '${data.day.toString().padLeft(2, '0')}';
  }

  String _dataItaliana(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  Future<void> _selezionaData() async {
    final oggi = DateUtils.dateOnly(DateTime.now());

    final dataBase = _dataSelezionata.isBefore(oggi)
        ? oggi
        : _dataSelezionata;

    final scelta = await showDatePicker(
      context: context,
      initialDate: _prossimoGiornoLavorativo(dataBase),
      firstDate: oggi,
      lastDate: DateTime(oggi.year + 2, 12, 31),
      selectableDayPredicate: (data) => !_isWeekend(data),
      helpText: 'Seleziona la data',
      confirmText: 'Conferma',
      cancelText: 'Annulla',
    );

    if (scelta != null && mounted) {
      setState(() => _dataSelezionata = scelta);
    }
  }

  Future<bool> _conferma({
    required String titolo,
    required String messaggio,
  }) async {
    final risultato = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titolo),
        content: Text(messaggio),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );

    return risultato == true;
  }

  Future<void> _eseguiOperazione(
    Future<int> Function() operazione, {
    required String messaggio,
  }) async {
    if (_operazioneInCorso) return;

    setState(() => _operazioneInCorso = true);

    try {
      final visiteEliminate = await operazione();

      ref.invalidate(indisponibilitaDottorePerDataProvider(_data));
      ref.invalidate(visiteDottorePerDataProvider(_data));
      ref.invalidate(dottoreDashboardProvider);

      if (!mounted) return;

      final dettaglio = visiteEliminate == 0
          ? ''
          : ' Eliminate definitivamente $visiteEliminate '
              '${visiteEliminate == 1 ? 'visita' : 'visite'}.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$messaggio$dettaglio')),
      );
    } catch (errore) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            errore.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _operazioneInCorso = false);
      }
    }
  }

  Future<void> _bloccaGiornata() async {
    if (_isWeekend(_dataSelezionata)) return;

    final confermato = await _conferma(
      titolo: 'Bloccare l’intera giornata?',
      messaggio:
          'La giornata ${_dataItaliana(_dataSelezionata)} '
          'non sarà prenotabile. Le visite già prenotate per '
          'questa data verranno eliminate definitivamente.',
    );

    if (!confermato || !mounted) return;

    await _eseguiOperazione(
      () => ref.read(dottoreRepositoryProvider).bloccaGiornata(_data),
      messaggio: 'Giornata bloccata.',
    );
  }

  Future<void> _bloccaOrario(String ora) async {
    if (_isWeekend(_dataSelezionata)) return;

    final confermato = await _conferma(
      titolo: 'Bloccare le $ora?',
      messaggio:
          'L’orario $ora del ${_dataItaliana(_dataSelezionata)} '
          'non sarà prenotabile. Se esiste una visita prenotata '
          'in questo orario, verrà eliminata definitivamente.',
    );

    if (!confermato || !mounted) return;

    await _eseguiOperazione(
      () => ref.read(dottoreRepositoryProvider).bloccaOrario(
            data: _data,
            ora: ora,
          ),
      messaggio: 'Orario bloccato.',
    );
  }

  Future<void> _rimuoviBlocco(String idBlocco) async {
    if (_operazioneInCorso || _isWeekend(_dataSelezionata)) return;

    setState(() => _operazioneInCorso = true);

    try {
      await ref
          .read(dottoreRepositoryProvider)
          .rimuoviIndisponibilita(idBlocco);

      ref.invalidate(indisponibilitaDottorePerDataProvider(_data));
      ref.invalidate(dottoreDashboardProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Indisponibilità rimossa. Le visite eliminate non vengono ripristinate.',
          ),
        ),
      );
    } catch (errore) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errore.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _operazioneInCorso = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final indisponibilita =
        ref.watch(indisponibilitaDottorePerDataProvider(_data));

    final weekend = _isWeekend(_dataSelezionata);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Disponibilità',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _bluScuro,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Gestisci i giorni e gli orari non prenotabili.',
                style: TextStyle(color: Color(0xFF526777)),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _operazioneInCorso ? null : _selezionaData,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(_dataItaliana(_dataSelezionata)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: weekend
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 40),
                    const Icon(
                      Icons.event_busy_outlined,
                      size: 64,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Giorno non disponibile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _bluScuro,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_dataItaliana(_dataSelezionata)} è un sabato '
                      'o una domenica. Nel fine settimana non è possibile '
                      'prenotare visite né modificare la disponibilità.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF526777),
                      ),
                    ),
                  ],
                )
              : indisponibilita.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (errore, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 42,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Impossibile caricare le indisponibilità.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () {
                              ref.invalidate(
                                indisponibilitaDottorePerDataProvider(_data),
                              );
                            },
                            child: const Text('Riprova'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (blocchi) {
                    final bloccoGiornata = blocchi
                        .where((blocco) => blocco['tuttoGiorno'] == true)
                        .firstOrNull;

                    final giornataBloccata = bloccoGiornata != null;

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _operazioneInCorso
                                ? null
                                : giornataBloccata
                                    ? () => _rimuoviBlocco(
                                          bloccoGiornata[
                                                  'idIndisponibilita']
                                              .toString(),
                                        )
                                    : _bloccaGiornata,
                            icon: Icon(
                              giornataBloccata
                                  ? Icons.lock_open_outlined
                                  : Icons.event_busy_outlined,
                            ),
                            label: Text(
                              giornataBloccata
                                  ? 'Rendi disponibile la giornata'
                                  : 'Blocca intera giornata',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: giornataBloccata
                                  ? const Color(0xFF247342)
                                  : _blu,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Orari di lavoro',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _bluScuro,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Seleziona un orario per bloccarlo o renderlo nuovamente disponibile.',
                          style: TextStyle(color: Color(0xFF526777)),
                        ),
                        const SizedBox(height: 14),
                        if (giornataBloccata)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'L’intera giornata è bloccata. '
                                      'Rimuovi il blocco giornaliero per '
                                      'gestire i singoli orari.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _orari.map((ora) {
                              final bloccoOra = blocchi
                                  .where(
                                    (blocco) =>
                                        blocco['tuttoGiorno'] != true &&
                                        blocco['ora'] == ora,
                                  )
                                  .firstOrNull;

                              final bloccato = bloccoOra != null;

                              return FilterChip(
                                avatar: Icon(
                                  bloccato
                                      ? Icons.lock_outline
                                      : Icons.access_time,
                                  size: 18,
                                ),
                                label: Text(
                                  bloccato ? '$ora · Bloccato' : ora,
                                ),
                                selected: bloccato,
                                showCheckmark: false,
                                selectedColor: const Color(0xFFFFE3E3),
                                onSelected: _operazioneInCorso
                                    ? null
                                    : (_) {
                                        if (bloccato) {
                                          _rimuoviBlocco(
                                            bloccoOra[
                                                    'idIndisponibilita']
                                                .toString(),
                                          );
                                        } else {
                                          _bloccaOrario(ora);
                                        }
                                      },
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 28),
                        const Text(
                          'Indisponibilità impostate',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _bluScuro,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (blocchi.isEmpty)
                          const Card(
                            elevation: 0,
                            color: Color(0xFFF5F9FC),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Nessun blocco per questa data.',
                                style: TextStyle(
                                  color: Color(0xFF526777),
                                ),
                              ),
                            ),
                          )
                        else
                          ...blocchi.map((blocco) {
                            final tuttoGiorno =
                                blocco['tuttoGiorno'] == true;
                            final ora = blocco['ora']?.toString();

                            return Card(
                              elevation: 0,
                              color: const Color(0xFFFFF5F5),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.event_busy_outlined,
                                  color: Colors.red,
                                ),
                                title: Text(
                                  tuttoGiorno
                                      ? 'Intera giornata'
                                      : 'Orario ${ora ?? ''}',
                                ),
                                subtitle: Text(
                                  _dataItaliana(_dataSelezionata),
                                ),
                                trailing: IconButton(
                                  tooltip: 'Rimuovi blocco',
                                  onPressed: _operazioneInCorso
                                      ? null
                                      : () => _rimuoviBlocco(
                                            blocco['idIndisponibilita']
                                                .toString(),
                                          ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            );
                          }),
                        if (_operazioneInCorso) ...[
                          const SizedBox(height: 16),
                          const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ],
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
