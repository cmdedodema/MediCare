
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'visite_paziente_screen.dart';
import 'profilo_paziente_screen.dart';

import '../../auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/visite_viewmodel.dart';

class HomePazienteScreen extends ConsumerStatefulWidget {
  const HomePazienteScreen({super.key});

  @override
  ConsumerState<HomePazienteScreen> createState() =>
      _HomePazienteScreenState();
}

class _HomePazienteScreenState
    extends ConsumerState<HomePazienteScreen> {
  int _pagina = 0;
  String? _idDottore;
  String? _oraSelezionata;

  late DateTime _dataSelezionata;
  late DateTime _meseVisualizzato;

  static const _blu = Color(0xFF2196F3);
  static const _bluScuro = Color(0xFF17324D);
  static const _sfondoAzzurro = Color(0xFFE3F2FD);

  @override
  void initState() {
    super.initState();

    final oggi = DateUtils.dateOnly(DateTime.now());
    _dataSelezionata = _prossimoGiornoFeriale(oggi);
    _meseVisualizzato = DateTime(
      _dataSelezionata.year,
      _dataSelezionata.month,
    );
  }

  DateTime _prossimoGiornoFeriale(DateTime data) {
    var risultato = data;

    while (risultato.weekday == DateTime.saturday ||
        risultato.weekday == DateTime.sunday) {
      risultato = risultato.add(const Duration(days: 1));
    }

    return risultato;
  }

  String _formattaData(DateTime data) =>
      '${data.year.toString().padLeft(4, '0')}-'
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}';

  String _nomeMese(int mese) {
    const mesi = [
      'Gennaio', 'Febbraio', 'Marzo', 'Aprile',
      'Maggio', 'Giugno', 'Luglio', 'Agosto',
      'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
    ];

    return mesi[mese - 1];
  }

  Future<void> _logout() async {
    await ref.read(authViewModelProvider.notifier).logout();

    if (!mounted) return;

    ref.read(authViewModelProvider).whenOrNull(
      error: (_, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante la disconnessione.'),
          ),
        );
      },
    );
  }

  void _cambiaMese(int differenza) {
    setState(() {
      _meseVisualizzato = DateTime(
        _meseVisualizzato.year,
        _meseVisualizzato.month + differenza,
      );

      _oraSelezionata = null;
    });
  }

  void _selezionaData(DateTime data) {
    setState(() {
      _dataSelezionata = data;
      _oraSelezionata = null;
    });
  }

  Future<void> _prenota() async {
    final idDottore = _idDottore;
    final ora = _oraSelezionata;

    if (idDottore == null || ora == null) return;

    final data = _formattaData(_dataSelezionata);
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma prenotazione'),
        content: Text(
          'Vuoi prenotare la visita il '
          '${_dataSelezionata.day.toString().padLeft(2, '0')}/'
          '${_dataSelezionata.month.toString().padLeft(2, '0')}/'
          '${_dataSelezionata.year} alle $ora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );

    if (conferma != true || !mounted) return;

    try {
      await ref.read(visiteRepositoryProvider).prenotaVisita(
            idDottore: idDottore,
            data: data,
            ora: ora,
          );

      ref.invalidate(
        orariDisponibiliProvider((
          dottore: idDottore,
          data: data,
        )),
      );

      if (!mounted) return;

      setState(() => _oraSelezionata = null);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visita prenotata con successo.'),
        ),
      );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authViewModelProvider).isLoading;

    final pagine = [
      _home(),
      const VisitePazienteScreen(),
      const ProfiloPazienteScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MediCare',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(child: pagine[_pagina]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pagina,
        onDestinationSelected: (index) {
          if (isLoading) return;

          if (index == 3) {
            _logout();
          } else {
            setState(() => _pagina = index);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Visite',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profilo',
          ),
          NavigationDestination(
            icon: Icon(Icons.logout),
            label: 'Esci',
          ),
        ],
      ),
    );
  }

  Widget _home() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _sfondoAzzurro,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  size: 42,
                  color: Color(0xFF1976D2),
                ),
                SizedBox(height: 16),
                Text(
                  'Benvenuto in MediCare',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: _bluScuro,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'La tua salute, al centro.',
                  style: TextStyle(color: Color(0xFF546E7A)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Prenota una visita',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: _bluScuro,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scegli il medico, una data e un orario disponibile.',
            style: TextStyle(color: Color(0xFF607D8B)),
          ),
          const SizedBox(height: 20),
          _sezioneMedico(),
          const SizedBox(height: 24),
          _calendario(),
          const SizedBox(height: 24),
          _sezioneOrari(),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _idDottore != null &&
                      _oraSelezionata != null
                  ? _prenota
                  : null,
              child: const Text('Conferma prenotazione'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sezioneMedico() {
    final dottori = ref.watch(dottoriProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Seleziona il medico',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
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
                'Non sono presenti medici registrati.',
              );
            }

            final idValido = lista.any(
              (dottore) => dottore['uid'] == _idDottore,
            );

            return DropdownButtonFormField<String>(
              key: ValueKey(idValido ? _idDottore : null),
              initialValue: idValido ? _idDottore : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Medico',
                prefixIcon: Icon(Icons.person_outline),
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
                  _oraSelezionata = null;
                });
              },
            );
          },
        ),
      ],
    );
  }

  Widget _calendario() {
    final oggi = DateUtils.dateOnly(DateTime.now());
    final primoGiorno = DateTime(
      _meseVisualizzato.year,
      _meseVisualizzato.month,
      1,
    );
    final offset = primoGiorno.weekday - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9E5EE)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: DateTime(
                          _meseVisualizzato.year,
                          _meseVisualizzato.month - 1,
                        ).isBefore(DateTime(oggi.year, oggi.month))
                    ? null
                    : () => _cambiaMese(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${_nomeMese(_meseVisualizzato.month)} '
                  '${_meseVisualizzato.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _bluScuro,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _cambiaMese(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              _GiornoSettimana('L'),
              _GiornoSettimana('M'),
              _GiornoSettimana('M'),
              _GiornoSettimana('G'),
              _GiornoSettimana('V'),
              _GiornoSettimana('S'),
              _GiornoSettimana('D'),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
            ),
            itemBuilder: (context, index) {
              final giorno = index - offset + 1;
              final numeroGiorni = DateUtils.getDaysInMonth(
                _meseVisualizzato.year,
                _meseVisualizzato.month,
              );

              if (giorno < 1 || giorno > numeroGiorni) {
                return const SizedBox.shrink();
              }

              final data = DateTime(
                _meseVisualizzato.year,
                _meseVisualizzato.month,
                giorno,
              );

              final passato = data.isBefore(oggi);
              final weekend = data.weekday == DateTime.saturday ||
                  data.weekday == DateTime.sunday;
              final selezionato =
                  DateUtils.isSameDay(data, _dataSelezionata);
              final disabilitato = passato || weekend;

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: disabilitato
                    ? null
                    : () => _selezionaData(data),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selezionato ? _blu : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: DateUtils.isSameDay(data, oggi)
                        ? Border.all(color: _blu)
                        : null,
                  ),
                  child: Text(
                    '$giorno',
                    style: TextStyle(
                      fontWeight: selezionato
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: selezionato
                          ? Colors.white
                          : disabilitato
                              ? Colors.grey.shade400
                              : _bluScuro,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Data selezionata: '
            '${_dataSelezionata.day.toString().padLeft(2, '0')}/'
            '${_dataSelezionata.month.toString().padLeft(2, '0')}/'
            '${_dataSelezionata.year}',
            style: const TextStyle(
              color: _bluScuro,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sezioneOrari() {
    if (_idDottore == null) {
      return const Text('Seleziona prima un medico.');
    }

    final data = _formattaData(_dataSelezionata);

    final orari = ref.watch(
      orariDisponibiliProvider((
        dottore: _idDottore!,
        data: data,
      )),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '2. Scegli un orario',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _bluScuro,
          ),
        ),
        const SizedBox(height: 12),
        orari.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (_, _) => const Text(
            'Impossibile caricare gli orari disponibili.',
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
                final selezionato = _oraSelezionata == ora;

                return ChoiceChip(
                  label: Text(ora),
                  selected: selezionato,
                  selectedColor: _sfondoAzzurro,
                  onSelected: (valore) {
                    setState(() {
                      _oraSelezionata = valore ? ora : null;
                    });
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _GiornoSettimana extends StatelessWidget {
  final String testo;

  const _GiornoSettimana(this.testo);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          testo,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF607D8B),
          ),
        ),
      ),
    );
  }
}

/*class _PaginaInPreparazione extends StatelessWidget {
  final String titolo;
  final String descrizione;
  final IconData icona;

  const _PaginaInPreparazione({
    required this.titolo,
    required this.descrizione,
    required this.icona,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icona, size: 64, color: const Color(0xFF2196F3)),
            const SizedBox(height: 20),
            Text(
              titolo,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF17324D),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              descrizione,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF607D8B)),
            ),
          ],
        ),
      ),
    );
  }
}*/
