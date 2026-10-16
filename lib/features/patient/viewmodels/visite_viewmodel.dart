import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/visite_repository.dart';

// Repository condiviso dalla sezione Paziente.
final visiteRepositoryProvider = Provider<VisiteRepository>((ref) {
  return VisiteRepository();
});

final dottoriProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(visiteRepositoryProvider).getDottori();
});

// Stream: gli orari vengono ricalcolati in tempo reale quando cambia
// una visita o un'indisponibilità del medico su Firestore.
final orariDisponibiliProvider =
    StreamProvider.autoDispose.family<List<String>, ({String dottore, String data})>(
  (ref, parametri) {
    return ref.read(visiteRepositoryProvider).watchOrariDisponibili(
          idDottore: parametri.dottore,
          data: parametri.data,
        );
  },
);

// Stream in tempo reale delle visite future del paziente.
final visitePazienteProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.read(visiteRepositoryProvider).watchVisitePaziente();
});
