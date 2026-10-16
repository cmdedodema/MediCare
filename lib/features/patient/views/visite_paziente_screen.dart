
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/visite_viewmodel.dart';

class VisitePazienteScreen extends ConsumerWidget {
  const VisitePazienteScreen({super.key});

  String _formattaData(String data) {
    final parti = data.split('-');

    if (parti.length != 3) return data;

    return '${parti[2]}/${parti[1]}/${parti[0]}';
  }

  Future<void> _cancellaVisita(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> visita,
  ) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancella visita'),
        content: Text(
          'Vuoi cancellare la visita del '
          '${_formattaData(visita['data']?.toString() ?? '')} '
          'alle ${visita['ora'] ?? ''}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Indietro'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('Cancella'),
          ),
        ],
      ),
    );

    if (conferma != true || !context.mounted) return;

    final idVisita = visita['idVisita']?.toString();
    final idDottore = visita['idDottore']?.toString();
    final data = visita['data']?.toString();

    if (idVisita == null ||
        idDottore == null ||
        data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile identificare la visita.'),
        ),
      );
      return;
    }

    try {
      // Elimina il documento da Firestore.
      await ref
          .read(visiteRepositoryProvider)
          .cancellaVisita(idVisita);

      // Aggiorna l'elenco delle visite del paziente.
      ref.invalidate(visitePazienteProvider);

      // Ricarica gli orari del medico per la data interessata.
      ref.invalidate(
        orariDisponibiliProvider((
          dottore: idDottore,
          data: data,
        )),
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Visita cancellata. L’orario è nuovamente disponibile.',
          ),
        ),
      );
    } catch (errore) {
      if (!context.mounted) return;

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
  Widget build(BuildContext context, WidgetRef ref) {
    final visite = ref.watch(visitePazienteProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(visitePazienteProvider);
            await ref.read(visitePazienteProvider.future);
          },
          child: visite.when(
            loading: () => ListView(
              physics: AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 220),
                Center(child: CircularProgressIndicator()),
              ],
            ),
            error: (errore, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 100),
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Impossibile caricare le visite.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    errore.toString(),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: FilledButton.icon(
                    onPressed: () {
                      ref.invalidate(visitePazienteProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Riprova'),
                  ),
                ),
              ],
            ),
            data: (lista) {
              if (lista.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: const [
                    SizedBox(height: 110),
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 64,
                      color: Color(0xFF2196F3),
                    ),
                    SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Non hai visite prenotate',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF17324D),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Le tue prossime visite appariranno qui.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF607D8B),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(
                      left: 4,
                      top: 8,
                      bottom: 16,
                    ),
                    child: Text(
                      'Le mie visite',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF17324D),
                      ),
                    ),
                  ),
                  for (final visita in lista)
                    Card(
                      color: Colors.white,
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 14),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.medical_services_outlined,
                                    color: Color(0xFF1976D2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        visita['nomeDottore']
                                                ?.toString() ??
                                            'Medico',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF17324D),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Data: ${_formattaData(visita['data']?.toString() ?? '')}',
                                        style: const TextStyle(
                                          color: Color(0xFF546E7A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Orario: ${visita['ora'] ?? ''}',
                                        style: const TextStyle(
                                          color: Color(0xFF546E7A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'Prenotata',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _cancellaVisita(
                                    context,
                                    ref,
                                    visita,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'Cancella',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
