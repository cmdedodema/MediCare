
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  // Firebase usa un'email tecnica, mentre il paziente accede con username.
  String _emailTecnica(String username) {
    return '${username.trim()}@medicare.local';
  }

  // Registra un paziente e salva il suo profilo in Firestore.
  Future<UserCredential> registerPatient({
    required String username,
    required String password,
    required String codiceFiscale,
    required String nome,
    required String cognome,
    required String dataNascita,
    required String email,
    required String telefono,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: _emailTecnica(username),
      password: password,
    );

    final user = credential.user;

    if (user == null) {
      throw Exception('Registrazione non riuscita.');
    }

    try {
      await _firestore.collection('utenti').doc(user.uid).set({
        'uid': user.uid,
        'username': username.trim(),
        'codiceFiscale': codiceFiscale.trim().toUpperCase(),
        'nome': nome.trim(),
        'cognome': cognome.trim(),
        'dataNascita': dataNascita.trim(),
        'email': email.trim(),
        'telefono': telefono.trim(),
        'ruolo': 'paziente',
      });
    } catch (_) {
      // Evita di lasciare un account senza il relativo profilo.
      try {
        await user.delete();
      } catch (_) {
        // L'errore originale di salvataggio verrà restituito.
      }
      rethrow;
    }

    return credential;
  }

  // Accesso tramite username e password, come nell'app Android.
  Future<UserCredential> login({
    required String username,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: _emailTecnica(username),
      password: password,
    );
  }

  // Recupera il ruolo dell'utente autenticato da Firestore.
  Future<String?> getUserRole(String uid) async {
    final document = await _firestore
        .collection('utenti')
        .doc(uid)
        .get();

    if (!document.exists) return null;

    return document.data()?['ruolo'] as String?;
  }


  // Recupera il profilo del paziente autenticato.
  Future<Map<String, dynamic>> getProfiloPaziente() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Devi effettuare l’accesso.');
    }

    final documento = await _firestore
        .collection('utenti')
        .doc(user.uid)
        .get();

    final dati = documento.data();

    if (dati == null || dati['ruolo'] != 'paziente') {
      throw Exception('Profilo paziente non trovato.');
    }

    return dati;
  }

  // Aggiorna i dati personali modificabili su Firestore.
  Future<void> aggiornaProfiloPaziente({
    required String nome,
    required String cognome,
    required String email,
    required String telefono,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Devi effettuare l’accesso.');
    }

    await _firestore.collection('utenti').doc(user.uid).update({
      'nome': nome.trim(),
      'cognome': cognome.trim(),
      'email': email.trim(),
      'telefono': telefono.trim(),
    });
  }


  // Termina la sessione.
  Future<void> logout() async {
    await _auth.signOut();
  }
}
