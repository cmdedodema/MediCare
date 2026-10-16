import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DottoreRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isWeekend(DateTime data) {
    return data.weekday == DateTime.saturday ||
        data.weekday == DateTime.sunday;
  }

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

  DateTime? _leggiData(String data) {
    try {
      final parti = data.split('-');

      if (parti.length != 3) return null;

      return DateTime(
        int.parse(parti[0]),
        int.parse(parti[1]),
        int.parse(parti[2]),
      );
    } catch (_) {
      return null;
    }
  }

  void _verificaGiornoLavorativo(String data) {
    final giorno = _leggiData(data);

    if (giorno == null) {
      throw Exception('La data selezionata non è valida.');
    }

    if (_isWeekend(giorno)) {
      throw Exception(
        'Sabato e domenica non sono giorni lavorativi.',
      );
    }
  }

  // Elimina definitivamente le visite non più valide.
  // Non conserva stati come "cancellato" o "effettuato".
  Future<void> _pulisciVisite(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documenti,
  ) async {
    final adesso = DateTime.now();
    final daEliminare = <DocumentReference<Map<String, dynamic>>>[];

    for (final documento in documenti) {
      final dati = documento.data();
      final stato =
          dati['stato']?.toString().trim().toLowerCase();

      if (stato != 'prenotato') {
        daEliminare.add(documento.reference);
        continue;
      }

      final dataOra = _leggiDataOra(
        dati['data']?.toString() ?? '',
        dati['ora']?.toString() ?? '',
      );

      // Se la data è malformata, non eliminiamo alla cieca
      // una prenotazione: sarà necessario verificarla.
      if (dataOra != null && !dataOra.isAfter(adesso)) {
        daEliminare.add(documento.reference);
      }
    }

    // Firestore permette al massimo 500 operazioni per batch.
    for (var i = 0; i < daEliminare.length; i += 450) {
      final fine = (i + 450 < daEliminare.length)
          ? i + 450
          : daEliminare.length;

      final batch = _db.batch();

      for (final riferimento in daEliminare.sublist(i, fine)) {
        batch.delete(riferimento);
      }

      await batch.commit();
    }
  }

  // Recupera il profilo del medico e i dati della Home.
  Future<Map<String, dynamic>> getDashboard() async {
    final utente = _auth.currentUser;

    if (utente == null) {
      throw Exception('Devi effettuare l’accesso.');
    }

    final profiloSnapshot =
        await _db.collection('utenti').doc(utente.uid).get();

    if (!profiloSnapshot.exists) {
      throw Exception('Profilo del medico non trovato.');
    }

    final profilo = profiloSnapshot.data()!;

    final visiteSnapshot = await _db
        .collection('visite')
        .where('idDottore', isEqualTo: utente.uid)
        .get();

    await _pulisciVisite(visiteSnapshot.docs);

    final adesso = DateTime.now();
    final oggi = DateTime(adesso.year, adesso.month, adesso.day);

    var visiteOggi = 0;
    final pazienti = <String>{};

    for (final documento in visiteSnapshot.docs) {
      final visita = documento.data();

      if (visita['stato']?.toString().trim().toLowerCase() !=
          'prenotato') {
        continue;
      }

      final dataOra = _leggiDataOra(
        visita['data']?.toString() ?? '',
        visita['ora']?.toString() ?? '',
      );

      if (dataOra == null || !dataOra.isAfter(adesso)) {
        continue;
      }

      final idPaziente = visita['idPaziente']?.toString();

      if (idPaziente != null && idPaziente.isNotEmpty) {
        pazienti.add(idPaziente);
      }

      final dataVisita = DateTime(
        dataOra.year,
        dataOra.month,
        dataOra.day,
      );

      if (dataVisita == oggi) {
        visiteOggi++;
      }
    }

    return {
      'nome': profilo['nome']?.toString() ?? '',
      'cognome': profilo['cognome']?.toString() ?? '',
      'visiteOggi': visiteOggi,
      'numeroPazienti': pazienti.length,
    };
  }

  // Recupera le visite future prenotate per una data.
  Future<List<Map<String, dynamic>>> getVisitePerData(
    String data,
  ) async {
    final utente = _auth.currentUser;

    if (utente == null) {
      throw Exception('Devi effettuare l’accesso.');
    }

    final snapshot = await _db
        .collection('visite')
        .where('idDottore', isEqualTo: utente.uid)
        .get();

    await _pulisciVisite(snapshot.docs);

    final adesso = DateTime.now();

    final visite = snapshot.docs.where((doc) {
      final dati = doc.data();

      if (dati['data']?.toString().trim() != data.trim()) {
        return false;
      }

      if (dati['stato']?.toString().trim().toLowerCase() !=
          'prenotato') {
        return false;
      }

      final dataOra = _leggiDataOra(
        dati['data']?.toString() ?? '',
        dati['ora']?.toString() ?? '',
      );

      return dataOra != null && dataOra.isAfter(adesso);
    }).map((doc) {
      return {
        ...doc.data(),
        'idVisita': doc.id,
      };
    }).toList();

    // Recupera i dati anagrafici dei pazienti.
    final visiteComplete = await Future.wait(
      visite.map((visita) async {
        final idPaziente =
            visita['idPaziente']?.toString() ?? '';

        var nome = 'Paziente';
        var cognome = '';

        if (idPaziente.isNotEmpty) {
          final profilo = await _db
              .collection('utenti')
              .doc(idPaziente)
              .get();

          final datiPaziente = profilo.data();

          if (datiPaziente != null) {
            nome = datiPaziente['nome']?.toString() ?? 'Paziente';
            cognome = datiPaziente['cognome']?.toString() ?? '';
          }
        }

        return {
          ...visita,
          'nomePaziente': nome,
          'cognomePaziente': cognome,
        };
      }),
    );

    visiteComplete.sort((a, b) {
      final oraA = a['ora']?.toString() ?? '';
      final oraB = b['ora']?.toString() ?? '';

      return oraA.compareTo(oraB);
    });

    return visiteComplete;
  }

  // Stream in tempo reale delle visite del medico per una data.
  // Firestore emette un nuovo valore quando una visita viene prenotata,
  // cancellata dal paziente o eliminata dal medico.
  Stream<List<Map<String, dynamic>>> watchVisitePerData(String data) {
    final utente = _auth.currentUser;

    if (utente == null) {
      return Stream.error(Exception('Devi effettuare l’accesso.'));
    }

    return _db
        .collection('visite')
        .where('idDottore', isEqualTo: utente.uid)
        .snapshots()
        .asyncMap((_) => getVisitePerData(data));
  }

  // Elimina definitivamente una visita del medico autenticato.
  Future<void> cancellaVisita(String idVisita) async {
    final utente = _auth.currentUser;

    if (utente == null) {
      throw Exception('Devi effettuare l’accesso.');
    }

    final riferimento = _db.collection('visite').doc(idVisita);
    final documento = await riferimento.get();

    if (!documento.exists) {
      throw Exception('La visita non esiste più.');
    }

    final dati = documento.data()!;

    if (dati['idDottore'] != utente.uid) {
      throw Exception('Non puoi eliminare questa visita.');
    }

    if (dati['stato']?.toString().trim().toLowerCase() !=
        'prenotato') {
      throw Exception('Questa visita non è più prenotata.');
    }

    await riferimento.delete();
  }

  // Recupera le indisponibilità del medico per una data.
  Future<List<Map<String, dynamic>>> getIndisponibilitaPerData(
    String data,
  ) async {
    final utente = _auth.currentUser;

    if (utente == null) {
      throw Exception('Devi effettuare l’accesso.');
    }

    final snapshot = await _db
        .collection('indisponibilita')
        .where('idDottore', isEqualTo: utente.uid)
        .get();

    return snapshot.docs
        .where((doc) => doc.data()['data'] == data)
        .map((doc) => {
              ...doc.data(),
              'idIndisponibilita': doc.id,
            })
        .toList();
  }

  // Stream in tempo reale delle indisponibilità del medico.
  Stream<List<Map<String, dynamic>>> watchIndisponibilitaPerData(
    String data,
  ) {
    final utente = _auth.currentUser;

    if (utente == null) {
      return Stream.error(Exception('Devi effettuare l’accesso.'));
    }

    return _db
        .collection('indisponibilita')
        .where('idDottore', isEqualTo: utente.uid)
        .snapshots()
        .asyncMap((_) => getIndisponibilitaPerData(data));
  }

  // Blocca una giornata ed elimina le visite prenotate.
  Future<int> bloccaGiornata(String data) async {
    _verificaGiornoLavorativo(data);

    final utente = _auth.currentUser;

    if (utente == null) {
      throw Exception('Devi effettuare l’accesso.');
    }

    final blocchiSnapshot = await _db
        .collection('indisponibilita')
        .where('idDottore', isEqualTo: utente.uid)
        .get();

    final blocchiGiorno = blocchiSnapshot.docs
        .where((doc) => doc.data()['data'] == data)
        .toList();

    final visiteSnapshot = await _db
        .collection('visite')
        .where('idDottore', isEqualTo: utente.uid)
        .get();

    final visiteDaEliminare = visiteSnapshot.docs.where((doc) {
      final visita = doc.data();

      return visita['data'] == data &&
          visita['stato']?.toString().trim().toLowerCase() ==
              'prenotato';
    }).toList();

    final giornateBloccate = blocchiGiorno
        .where((doc) => doc.data()['tuttoGiorno'] == true)
        .toList();

    final batch = _db.batch();
    var operazioni = 0;

    if (giornateBloccate.isEmpty) {
      for (final blocco in blocchiGiorno) {
        batch.delete(blocco.reference);
        operazioni++;
      }

      final nuovoBlocco =
          _db.collection('indisponibilita').doc();

      batch.set(nuovoBlocco, {
        'idDottore': utente.uid,
        'data': data,
        'tuttoGiorno': true,
      });

      operazioni++;
    } else {
      for (final blocco in blocchiGiorno) {
        if (blocco.id != giornateBloccate.first.id) {
          batch.delete(blocco.reference);
          operazioni++;
        }
      }
    }

    for (final visita in visiteDaEliminare) {
      batch.delete(visita.reference);
      operazioni++;
    }

    if (operazioni == 0) return 0;

    if (operazioni > 500) {
      throw Exception(
        'Troppe operazioni per un unico aggiornamento.',
      );
    }

    await batch.commit();

    return visiteDaEliminare.length;
  }

  // Blocca un orario ed elimina l'eventuale visita prenotata.
  Future<int> bloccaOrario({
    required String data,
    required String ora,
  }) async {
    _verificaGiornoLavorativo(data);

    final utente = _auth.currentUser;

    if (utente == null) {
      throw Exception('Devi effettuare l’accesso.');
    }

    final blocchiSnapshot = await _db
        .collection('indisponibilita')
        .where('idDottore', isEqualTo: utente.uid)
        .get();

    final blocchiGiorno = blocchiSnapshot.docs
        .where((doc) => doc.data()['data'] == data)
        .toList();

    if (blocchiGiorno.any(
      (doc) => doc.data()['tuttoGiorno'] == true,
    )) {
      throw Exception('La giornata è già bloccata interamente.');
    }

    final orarioGiaBloccato = blocchiGiorno.any(
      (doc) =>
          doc.data()['tuttoGiorno'] != true &&
          doc.data()['ora']?.toString().trim() == ora.trim(),
    );

    final visiteSnapshot = await _db
        .collection('visite')
        .where('idDottore', isEqualTo: utente.uid)
        .get();

    final visiteDaEliminare = visiteSnapshot.docs.where((doc) {
      final visita = doc.data();

      return visita['data']?.toString().trim() == data.trim() &&
          visita['ora']?.toString().trim() == ora.trim() &&
          visita['stato']?.toString().trim().toLowerCase() ==
              'prenotato';
    }).toList();

    final batch = _db.batch();
    var operazioni = 0;

    if (!orarioGiaBloccato) {
      final nuovoBlocco =
          _db.collection('indisponibilita').doc();

      batch.set(nuovoBlocco, {
        'idDottore': utente.uid,
        'data': data,
        'ora': ora,
        'tuttoGiorno': false,
      });

      operazioni++;
    }

    for (final visita in visiteDaEliminare) {
      batch.delete(visita.reference);
      operazioni++;
    }

    if (operazioni == 0) return 0;

    if (operazioni > 500) {
      throw Exception(
        'Troppe operazioni per un unico aggiornamento.',
      );
    }

    await batch.commit();

    return visiteDaEliminare.length;
  }

  // Rimuove un blocco. Le visite già eliminate non vengono ripristinate.
  Future<void> rimuoviIndisponibilita(
    String idIndisponibilita,
  ) async {
    final utente = _auth.currentUser;

    if (utente == null) {
      throw Exception('Devi effettuare l’accesso.');
    }

    final riferimento =
        _db.collection('indisponibilita').doc(idIndisponibilita);

    final documento = await riferimento.get();

    if (!documento.exists) {
      throw Exception('L’indisponibilità non esiste più.');
    }

    final dati = documento.data()!;

    if (dati['idDottore'] != utente.uid) {
      throw Exception(
        'Non puoi modificare l’indisponibilità di un altro medico.',
      );
    }

    await riferimento.delete();
  }
}
