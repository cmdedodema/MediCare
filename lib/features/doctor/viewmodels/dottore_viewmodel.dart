import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/dottore_repository.dart';

// Repository condiviso dalla sezione Medico.
final dottoreRepositoryProvider = Provider<DottoreRepository>((ref) {
  return DottoreRepository();
});

// Dati riepilogativi della Home.
final dottoreDashboardProvider =
    FutureProvider<Map<String, dynamic>>((ref) {
  return ref.read(dottoreRepositoryProvider).getDashboard();
});

// Stream delle visite prenotate per una data specifica.
final visiteDottorePerDataProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, data) {
    return ref.read(dottoreRepositoryProvider).watchVisitePerData(data);
  },
);

// Stream delle indisponibilità del medico per una data specifica.
final indisponibilitaDottorePerDataProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, data) {
    return ref
        .read(dottoreRepositoryProvider)
        .watchIndisponibilitaPerData(data);
  },
);
