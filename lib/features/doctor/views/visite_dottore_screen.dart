import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/dottore_viewmodel.dart';

class VisiteDottoreScreen extends ConsumerStatefulWidget {
  const VisiteDottoreScreen({super.key});

  @override
  ConsumerState<VisiteDottoreScreen> createState() =>
      _VisiteDottoreScreenState();
}

class _VisiteDottoreScreenState
    extends ConsumerState<VisiteDottoreScreen> {
  static const _blu = Color(0xFF2196F3);
  static const _bluScuro = Color(0xFF17324D);

  DateTime _dataSelezionata = DateTime.now();
  final Set<String> _eliminazioniInCorso = {};

  String get _dataFirestore {
    final data = _dataSelezionata;

    return '${data.year.toString().padLeft(4, '0')}-'
        '${data.month.toString().padLeft(2, '0')}-'
        '${data.day.toString().padLeft(2, '0')}';
  }

  String _formattaData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  // Sabato e domenica non sono giorni lavorativi.
  bool _isWeekend(DateTime data) {
    return data.weekday == DateTime.saturday ||
        data.weekday == DateTime.sunday;
  }

  // Il calendario deve iniziare da una data selezionabile.
  DateTime _prossimoGiornoLavorativo(DateTime data) {
    var risultato = DateUtils.dateOnly(data);

    while (_isWeekend(risultato)) {
      risultato = risultato.add(const Duration(days: 1));
    }

    return risultato;
  }

  Future<void> _selezionaData() async {
    final oggi = DateUtils.dateOnly(DateTime.now());

    // Se la data corrente è nel passato, si parte da oggi.
    // Se è sabato o domenica, si passa al lunedì successivo.
    final dataBase = _dataSelezionata.isBefore(oggi)
        ? oggi
        : _dataSelezionata;

    final scelta = await showDatePicker(
      context: context,
      initialDate: _prossimoGiornoLavorativo(dataBase),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),

      // Impedisce materialmente di selezionare il weekend.
      selectableDayPredicate: (data) => !_isWeekend(data),

      helpText: 'Seleziona il giorno delle visite',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
    );

    if (scelta != null && mounted) {
      setState(() {
        _dataSelezionata = scelta;
      });
    }
  }

  Future<void> _aggiorna() async {
    ref.invalidate(visiteDottorePerDataProvider(_dataFirestore));
    ref.invalidate(dottoreDashboardProvider);

    try {
      await ref.read(
        visiteDottorePerDataProvider(_dataFirestore).future,
      );
    } catch (_) {
      // L'eventuale errore viene mostrato dal provider nella schermata.
    }
  }

  Future<void> _confermaEliminazione(
    Map<String, dynamic> visita,
  ) async {
    final idVisita = visita['idVisita']?.toString() ?? '';

    if (idVisita.isEmpty) return;

    final conferma = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminare la visita?'),
        content: Text(
          'La visita di ${visita['nomePaziente']} '
          '${visita['cognomePaziente']} del '
          '${_formattaData(_dataSelezionata)} alle '
          '${visita['ora']} verrà eliminata definitivamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (conferma != true || !mounted) return;

    setState(() => _eliminazioniInCorso.add(idVisita));

    try {
      await ref
          .read(dottoreRepositoryProvider)
          .cancellaVisita(idVisita);

      ref.invalidate(visiteDottorePerDataProvider(_dataFirestore));
      ref.invalidate(dottoreDashboardProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Visita eliminata. L’orario è nuovamente disponibile.',
          ),
        ),
      );
    } catch (errore) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossibile eliminare la visita: '
            '${errore.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _eliminazioniInCorso.remove(idVisita));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visiteAsync =
        ref.watch(visiteDottorePerDataProvider(_dataFirestore));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Calendario visite',
                style: TextStyle(
                  color: _bluScuro,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Consulta e gestisci gli appuntamenti prenotati.',
                style: TextStyle(color: Color(0xFF526777)),
              ),
              const SizedBox(height: 18),
              InkWell(
                onTap: _selezionaData,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5FD),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFD0E7F7),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        color: _blu,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Data selezionata',
                              style: TextStyle(
                                color: Color(0xFF526777),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _formattaData(_dataSelezionata),
                              style: const TextStyle(
                                color: _bluScuro,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.edit_calendar_outlined,
                        color: _blu,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: visiteAsync.when(
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
                      'Impossibile caricare le visite.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _aggiorna,
                      child: const Text('Riprova'),
                    ),
                  ],
                ),
              ),
            ),
            data: (visite) {
              return RefreshIndicator(
                onRefresh: _aggiorna,
                child: visite.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 55),
                          Icon(
                            Icons.event_available_outlined,
                            size: 64,
                            color: Colors.blueGrey.shade200,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Nessuna visita prenotata',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _bluScuro,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Non risultano appuntamenti per il '
                            '${_formattaData(_dataSelezionata)}.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF526777),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        children: [
                          Text(
                            '${visite.length} '
                            '${visite.length == 1 ? 'visita' : 'visite'}',
                            style: const TextStyle(
                              color: _bluScuro,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...visite.map((visita) {
                            final idVisita =
                                visita['idVisita']?.toString() ?? '';
                            final nome =
                                visita['nomePaziente']?.toString() ??
                                    'Paziente';
                            final cognome =
                                visita['cognomePaziente']?.toString() ??
                                    '';
                            final ora =
                                visita['ora']?.toString() ?? '--:--';
                            final eliminazioneInCorso =
                                _eliminazioniInCorso.contains(idVisita);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(
                                  color: Color(0xFFD9E5EE),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEAF5FD),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: const Icon(
                                            Icons.person_outline,
                                            color: _blu,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '$nome $cognome'.trim(),
                                                style: const TextStyle(
                                                  color: _bluScuro,
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.access_time,
                                                    size: 17,
                                                    color: _blu,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    ora,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE5F5EA),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: const Text(
                                            'Prenotata',
                                            style: TextStyle(
                                              color: Color(0xFF247342),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    const Divider(height: 1),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: eliminazioneInCorso
                                            ? null
                                            : () =>
                                                _confermaEliminazione(visita),
                                        icon: eliminazioneInCorso
                                            ? const SizedBox(
                                                width: 17,
                                                height: 17,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                              ),
                                        label: Text(
                                          eliminazioneInCorso
                                              ? 'Eliminazione...'
                                              : 'Elimina visita',
                                          style: const TextStyle(
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}