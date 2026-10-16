
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'visite_dottore_screen.dart';

import 'disponibilita_dottore_screen.dart';


import '../../auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/dottore_viewmodel.dart';

class HomeDottoreScreen extends ConsumerStatefulWidget {
  const HomeDottoreScreen({super.key});

  @override
  ConsumerState<HomeDottoreScreen> createState() =>
      _HomeDottoreScreenState();
}

class _HomeDottoreScreenState
    extends ConsumerState<HomeDottoreScreen> {
  int _pagina = 0;

  static const _blu = Color(0xFF2196F3);
  static const _bluScuro = Color(0xFF17324D);

  Future<void> _logout() async {
    try {
      await ref.read(authViewModelProvider.notifier).logout();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Errore durante la disconnessione.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dottoreDashboardProvider);

    final pagine = [
      _home(dashboard),
      const VisiteDottoreScreen(),
      const DisponibilitaDottoreScreen(),

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
            icon: Icon(Icons.event_available_outlined),
            selectedIcon: Icon(Icons.event_available),
            label: 'Disponibilità',
          ),
          NavigationDestination(
            icon: Icon(Icons.logout),
            label: 'Esci',
          ),
        ],
      ),
    );
  }

  Widget _home(AsyncValue<Map<String, dynamic>> dashboard) {
    return dashboard.when(
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
                size: 44,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              const Text(
                'Impossibile caricare i dati del medico.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  ref.invalidate(dottoreDashboardProvider);
                },
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
      data: (dati) {
        final nome =
            '${dati['nome']} ${dati['cognome']}'.trim();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dottoreDashboardProvider);
            await ref.read(dottoreDashboardProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: _blu,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.medical_services_outlined,
                      color: Colors.white,
                      size: 34,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Benvenuto, Dott.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nome.isEmpty ? 'Medico' : nome,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Ecco il riepilogo della tua attività.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Riepilogo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bluScuro,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatisticaCard(
                      icona: Icons.access_time,
                      titolo: 'Visite oggi',
                      valore: '${dati['visiteOggi']}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatisticaCard(
                      icona: Icons.people_outline,
                      titolo: 'Pazienti',
                      valore: '${dati['numeroPazienti']}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(
                    color: Color(0xFFD9E5EE),
                  ),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.calendar_month_outlined,
                    color: _blu,
                    size: 30,
                  ),
                  title: const Text(
                    'Gestisci le visite',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Consulta il calendario degli appuntamenti.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() => _pagina = 1),
                ),
              ),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(
                    color: Color(0xFFD9E5EE),
                  ),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.event_busy_outlined,
                    color: _blu,
                    size: 30,
                  ),
                  title: const Text(
                    'Gestisci disponibilità',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Imposta giorni e orari non disponibili.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() => _pagina = 2),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatisticaCard extends StatelessWidget {
  final IconData icona;
  final String titolo;
  final String valore;

  const _StatisticaCard({
    required this.icona,
    required this.titolo,
    required this.valore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9E5EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icona,
            color: const Color(0xFF2196F3),
            size: 28,
          ),
          const SizedBox(height: 14),
          Text(
            valore,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF17324D),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            titolo,
            style: const TextStyle(color: Color(0xFF526777)),
          ),
        ],
      ),
    );
  }
}
