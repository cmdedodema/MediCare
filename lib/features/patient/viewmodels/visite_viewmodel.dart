
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/visite_repository.dart';

final visiteRepositoryProvider = Provider<VisiteRepository>((ref) {
  return VisiteRepository();
});

final dottoriProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(visiteRepositoryProvider).getDottori();
});

final orariDisponibiliProvider =
    FutureProvider.family<List<String>, ({String dottore, String data})>(
  (ref, parametri) {
    return ref.read(visiteRepositoryProvider).getOrariDisponibili(
          idDottore: parametri.dottore,
          data: parametri.data,
        );
  },
);

// Elenco delle visite future del paziente.
final visitePazienteProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(visiteRepositoryProvider).getVisitePaziente();
});
