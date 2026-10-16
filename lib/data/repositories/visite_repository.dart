import 'dart:async';

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

  bool _isWeekend(DateTime data) =>
      data.weekday == DateTime.saturday ||
      data.weekday == DateTime.sunday;

  DateTime? _leggiDataOra(String data, String ora) {
    try {
      final dataPulita = data.trim();
      final oraPulita = ora.trim();

      if (dataPulita.isEmpty || oraPulita.isEmpty) {
        return null;
      }

      final oraCompleta =
          oraPulita.length == 5 ? '$oraPulita:00' : oraPulita;

      return DateTime.parse('${dataPulita}T$oraCompleta');
    } catch (_) {
      return null;
    }
  }

  String _formattaData(DateTime data) =>
      '${data.year.toString().padLeft(4, '0')}-'
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}';

  // Elimina le visite che non devono più essere conservate.
  Future<void> _pulisciVisite(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documenti,
  ) async {
    final adesso = DateTime.now();

    final eliminazioni = <Future<void>>[];

    for (final documento in documenti) {
      final dati = documento.data();
      final stato =
          dati['stato']?.toString().trim().toLowerCase();

      final data = dati['data']?.toString() ?? '';
      final ora = dati['ora']?.toString() ?? '';
      final dataOra = _leggiDataOra(data, ora);

      // Nel database devono restare solo le visite prenotate.
      // Le visite non valide o scadute vengono eliminate.
      if (stato != 'prenotato' ||
          dataOra == null ||
          !dataOra.isAfter(adesso)) {
        eliminazioni.add(documento.reference.delete());
      }
    }

    if (eliminazioni.isNotEmpty) {
      await Future.wait(eliminazioni);
    }
  }

  // Recupera i medici.
  Future<List<Map<String, dynamic>>> getDottori() async {
    final snapshot = await _db
        .collection('utenti')
        .where('ruolo', isEqualTo: 'dottore')
        .get();

    return snapshot.docs.map((doc) {
      return {
        ...doc.data(),
        'uid': doc.id,
      };
    }).toList();
  }

  // Recupera le visite future prenotate di un medico.
  Future<List<Map<String, dynamic>>> getVisiteDottore(
    String idDottore,
  ) async {
    final snapshot = await _db
        .collection('visite')
        .where('idDottore', isEqualTo: idDottore)
        .get();

    await _pulisciVisite(snapshot.docs);

    final adesso = DateTime.now();
    final risultato = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final dati = doc.data();
      final stato =
          dati['stato']?.toString().trim().toLowerCase();

      if (stato != 'prenotato') continue;

      final dataOra = _leggiDataOra(
        dati['data']?.toString() ?? '',
        dati['ora']?.toString() ?? '',
      );

      if (dataOra == null || !dataOra.isAfter(adesso)) {
        continue;
      }

      risultato.add({
        ...dati,
        'idVisita': doc.id,
      });
    }

    risultato.sort((a, b) {
      final dataA = _leggiDataOra(
        a['data']?.toString() ?? '',
        a['ora']?.toString() ?? '',
      );
      final dataB = _leggiDataOra(
        b['data']?.toString() ?? '',
        b['ora']?.toString() ?? '',
      );

      if (dataA == null) return 1;
      if (dataB == null) return -1;

      return dataA.compareTo(dataB);
    });

    return risultato;
  }

  // Calcola gli orari disponibili per una data.
  Future<List<String>> getOrariDisponibili({
    required String idDottore,
    required String data,
  }) async {
    final dataOra = _leggiDataOra(data, '00:00');

    if (dataOra == null || _isWeekend(dataOra)) {
      return [];
    }

    final adesso = DateTime.now();
    final oggi = DateTime(adesso.year, adesso.month, adesso.day);
    final giorno = DateTime(
      dataOra.year,
      dataOra.month,
      dataOra.day,
    );

    if (giorno.isBefore(oggi)) {
      return [];
    }

    final indisponibilita = await _db
        .collection('indisponibilita')
        .where('idDottore', isEqualTo: idDottore)
        .where('data', isEqualTo: data)
        .get();

    final blocchi =
        indisponibilita.docs.map((doc) => doc.data()).toList();

    if (blocchi.any((blocco) => blocco['tuttoGiorno'] == true)) {
      return [];
    }

    final visite = await getVisiteDottore(idDottore);

    final orariPrenotati = visite.where((visita) {
      return visita['data']?.toString().trim() == data.trim();
    }).map((visita) {
      return visita['ora']?.toString().trim();
    }).toSet();

    return orariLavorativi.where((ora) {
      final dataOraVisita = _leggiDataOra(data, ora);

      if (dataOraVisita == null ||
          !dataOraVisita.isAfter(adesso)) {
        return false;
      }

      final bloccato = blocchi.any((blocco) {
        return blocco['tuttoGiorno'] != true &&
            blocco['ora']?.toString().trim() == ora;
      });

      return !bloccato && !orariPrenotati.contains(ora);
    }).toList();
  }

  // Stream in tempo reale degli orari disponibili.
  // Si aggiorna quando cambia una visita o un'indisponibilità su Firestore,
  // anche se la modifica viene effettuata da un altro dispositivo.
  Stream<List<String>> watchOrariDisponibili({
    required String idDottore,
    required String data,
  }) {
    final controller = StreamController<List<String>>();
    var versioneRichiesta = 0;

    Future<void> aggiorna() async {
      final versione = ++versioneRichiesta;

      try {
        final risultato = await getOrariDisponibili(
          idDottore: idDottore,
          data: data,
        );

        // Ignora eventuali risultati vecchi arrivati dopo una richiesta nuova.
        if (!controller.isClosed && versione == versioneRichiesta) {
          controller.add(risultato);
        }
      } catch (errore, stackTrace) {
        if (!controller.isClosed && versione == versioneRichiesta) {
          controller.addError(errore, stackTrace);
        }
      }
    }

    final visiteSubscription = _db
        .collection('visite')
        .where('idDottore', isEqualTo: idDottore)
        .snapshots()
        .listen(
          (_) => aggiorna(),
          onError: (Object errore, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(errore, stackTrace);
            }
          },
        );

    final indisponibilitaSubscription = _db
        .collection('indisponibilita')
        .where('idDottore', isEqualTo: idDottore)
        .snapshots()
        .listen(
          (_) => aggiorna(),
          onError: (Object errore, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(errore, stackTrace);
            }
          },
        );

    controller.onCancel = () async {
      await visiteSubscription.cancel();
      await indisponibilitaSubscription.cancel();
    };

    return controller.stream;
  }

  // Recupera tutte le visite future del paziente.
  Future<List<Map<String, dynamic>>> getVisitePaziente() async {
    final paziente = _auth.currentUser;

    if (paziente == null) {
      throw Exception('Devi effettuare l’accesso.');
    }

    final snapshot = await _db
        .collection('visite')
        .where('idPaziente', isEqualTo: paziente.uid)
        .get();

    await _pulisciVisite(snapshot.docs);

    final adesso = DateTime.now();
    final risultato = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final dati = doc.data();

      if (dati['stato']?.toString().trim().toLowerCase() !=
          'prenotato') {
        continue;
      }

      final data = dati['data']?.toString() ?? '';
      final ora = dati['ora']?.toString() ?? '';
      final dataOra = _leggiDataOra(data, ora);

      if (dataOra == null || !dataOra.isAfter(adesso)) {
        continue;
      }

      final idDottore = dati['idDottore']?.toString() ?? '';
      var nomeDottore = 'Medico';

      if (idDottore.isNotEmpty) {
        final dottore =
            await _db.collection('utenti').doc(idDottore).get();

        final datiDottore = dottore.data();

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

    risultato.sort((a, b) {
      final dataA = _leggiDataOra(
        a['data']?.toString() ?? '',
        a['ora']?.toString() ?? '',
      );
      final dataB = _leggiDataOra(
        b['data']?.toString() ?? '',
        b['ora']?.toString() ?? '',
      );

      if (dataA == null) return 1;
      if (dataB == null) return -1;

      return dataA.compareTo(dataB);
    });

    return risultato;
  }

  // Stream in tempo reale delle visite del paziente.
  // La cancellazione da parte del paziente o del medico aggiorna la lista
  // senza dover uscire e rientrare nella schermata.
  Stream<List<Map<String, dynamic>>> watchVisitePaziente() {
    final paziente = _auth.currentUser;

    if (paziente == null) {
      return Stream.error(Exception('Devi effettuare l’accesso.'));
    }

    return _db
        .collection('visite')
        .where('idPaziente', isEqualTo: paziente.uid)
        .snapshots()
        .asyncMap((_) => getVisitePaziente());
  }

  // Salva una nuova prenotazione.
  Future<void> prenotaVisita({
    required String idDottore,
    required String data,
    required String ora,
  }) async {
    final paziente = _auth.currentUser;

    if (paziente == null) {
      throw Exception('Devi effettuare l’accesso.');
    }

    final dataOra = _leggiDataOra(data, ora);

    if (dataOra == null) {
      throw Exception('La data o l’orario non sono validi.');
    }

    if (_isWeekend(dataOra)) {
      throw Exception(
        'Non è possibile prenotare di sabato o domenica.',
      );
    }

    if (!dataOra.isAfter(DateTime.now())) {
      throw Exception(
        'Non è possibile prenotare una visita nel passato.',
      );
    }

    final disponibili = await getOrariDisponibili(
      idDottore: idDottore,
      data: data,
    );

    if (!disponibili.contains(ora)) {
      throw Exception(
        'Questo orario non è disponibile. Aggiorna gli orari.',
      );
    }

    final documento = _db.collection('visite').doc();

    await documento.set({
      'idVisita': documento.id,
      'idPaziente': paziente.uid,
      'idDottore': idDottore,
      'data': _formattaData(dataOra),
      'ora': ora,
      'stato': 'prenotato',
    });
  }

  // Elimina definitivamente una visita del paziente.
  Future<void> cancellaVisita(String idVisita) async {
    final paziente = _auth.currentUser;

    if (paziente == null) {
      throw Exception('Devi effettuare l’accesso.');
    }

    final riferimento = _db.collection('visite').doc(idVisita);
    final documento = await riferimento.get();

    if (!documento.exists) {
      throw Exception('La visita non esiste più.');
    }

    final dati = documento.data()!;

    if (dati['idPaziente'] != paziente.uid) {
      throw Exception('Non puoi cancellare questa visita.');
    }

    if (dati['stato']?.toString().trim().toLowerCase() !=
        'prenotato') {
      throw Exception('Questa visita non è più prenotata.');
    }

    await riferimento.delete();
  }
}