
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VisiteRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const orariLavorativi = [
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '15:00',
    '16:00',
    '17:00',
  ];

  // Recupera i medici registrati.
  Future<List<Map<String, dynamic>>> getDottori() async {
    final snapshot = await _db
        .collection('utenti')
        .where('ruolo', isEqualTo: 'dottore')
        .get();

    return snapshot.docs.map((doc) {
      return {...doc.data(), 'uid': doc.id};
    }).toList();
  }

  // Recupera tutte le visite di un medico.
  Future<List<Map<String, dynamic>>> getVisiteDottore(
    String idDottore,
  ) async {
    final snapshot = await _db
        .collection('visite')
        .where('idDottore', isEqualTo: idDottore)
        .get();

    return snapshot.docs.map((doc) {
      return {...doc.data(), 'idVisita': doc.id};
    }).toList();
  }

  // Calcola gli orari disponibili escludendo:
  // - gli orari bloccati dal medico;
  // - gli orari delle visite ancora prenotate.
  Future<List<String>> getOrariDisponibili({
    required String idDottore,
    required String data,
  }) async {
    final indisponibilita = await _db
        .collection('indisponibilita')
        .where('idDottore', isEqualTo: idDottore)
        .where('data', isEqualTo: data)
        .get();

    final blocchi = indisponibilita.docs
        .map((doc) => doc.data())
        .toList();

    // Se il medico è indisponibile per tutto il giorno,
    // non viene mostrato nessun orario.
    if (blocchi.any((blocco) => blocco['tuttoGiorno'] == true)) {
      return [];
    }

    final visite = await getVisiteDottore(idDottore);

    // Soltanto le visite prenotate occupano un orario.
    // Le visite cancellate vengono eliminate dal database.
    final prenotati = visite
        .where(
          (visita) =>
              visita['data'] == data &&
              visita['stato']?.toString().toLowerCase() ==
                  'prenotato',
        )
        .map((visita) => visita['ora']?.toString())
        .toSet();

    return orariLavorativi.where((ora) {
      final bloccato = blocchi.any(
        (blocco) =>
            blocco['tuttoGiorno'] != true &&
            blocco['ora'] == ora,
      );

      return !bloccato && !prenotati.contains(ora);
    }).toList();
  }

  // Recupera le visite future ancora prenotate dal paziente.
  Future<List<Map<String, dynamic>>> getVisitePaziente() async {
    final paziente = _auth.currentUser;

    if (paziente == null) {
      throw Exception('Devi effettuare l’accesso.');
    }

    final snapshot = await _db
        .collection('visite')
        .where('idPaziente', isEqualTo: paziente.uid)
        .get();

    final adesso = DateTime.now();
    final risultato = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final dati = doc.data();

      // Mostra soltanto le visite ancora prenotate.
      if (dati['stato']?.toString().toLowerCase() != 'prenotato') {
        continue;
      }

      final data = dati['data']?.toString() ?? '';
      final ora = dati['ora']?.toString() ?? '';

      DateTime dataOra;

      try {
        dataOra = DateTime.parse('$data' 'T$ora:00');
      } catch (_) {
        // Ignora i documenti con data o ora non valide.
        continue;
      }

      if (!dataOra.isAfter(adesso)) {
        continue;
      }

      final idDottore = dati['idDottore']?.toString() ?? '';
      String nomeDottore = 'Medico';

      if (idDottore.isNotEmpty) {
        final documentoDottore =
            await _db.collection('utenti').doc(idDottore).get();

        final datiDottore = documentoDottore.data();

        if (datiDottore != null) {
          nomeDottore =
              '${datiDottore['nome'] ?? ''} '
              '${datiDottore['cognome'] ?? ''}'.trim();

          if (nomeDottore.isEmpty) {
            nomeDottore = 'Medico';
          }
        }
      }

      risultato.add({
        ...dati,
        'idVisita': doc.id,
        'nomeDottore': nomeDottore,
      });
    }

    // Ordina le visite dalla più vicina alla più lontana.
    risultato.sort((a, b) {
      final dataA = DateTime.parse(
        '${a['data']}T${a['ora']}:00',
      );
      final dataB = DateTime.parse(
        '${b['data']}T${b['ora']}:00',
      );

      return dataA.compareTo(dataB);
    });

    return risultato;
  }

  // Prenota una visita salvandola su Firestore.
  Future<void> prenotaVisita({
    required String idDottore,
    required String data,
    required String ora,
  }) async {
    final paziente = _auth.currentUser;

    if (paziente == null) {
      throw Exception('Devi effettuare l’accesso.');
    }

    final disponibili = await getOrariDisponibili(
      idDottore: idDottore,
      data: data,
    );

    if (!disponibili.contains(ora)) {
      throw Exception(
        'Questo orario non è più disponibile. Aggiorna gli orari.',
      );
    }

    final documento = _db.collection('visite').doc();

    await documento.set({
      'idVisita': documento.id,
      'idPaziente': paziente.uid,
      'idDottore': idDottore,
      'data': data,
      'ora': ora,
      'stato': 'prenotato',
    });
  }

  // Cancella definitivamente una visita del paziente.
  Future<void> cancellaVisita(String idVisita) async {
    final paziente = _auth.currentUser;

    if (paziente == null) {
      throw Exception('Devi effettuare l’accesso.');
    }

    final riferimento = _db
        .collection('visite')
        .doc(idVisita);

    final documento = await riferimento.get();

    if (!documento.exists) {
      throw Exception('La visita non esiste più.');
    }

    final dati = documento.data()!;

    // Impedisce al paziente di eliminare visite altrui.
    if (dati['idPaziente'] != paziente.uid) {
      throw Exception('Non puoi cancellare questa visita.');
    }

    if (dati['stato']?.toString().toLowerCase() != 'prenotato') {
      throw Exception('Questa visita non è più prenotata.');
    }

    // Eliminazione definitiva del documento.
    await riferimento.delete();
  }
}
