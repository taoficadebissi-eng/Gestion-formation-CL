import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/firebase/firestore_helpers.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get utilisateurActuel => _auth.currentUser;

  Future<UserCredential> connexion(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Crée un compte formateur/apprenant sans déconnecter l'admin : le compte
  /// est créé via une instance Firebase secondaire (session séparée), puis
  /// le profil est écrit avec la session de l'admin, ce que les règles
  /// Firestore autorisent uniquement pour le propriétaire du centre.
  /// Retourne l'id du nouvel utilisateur.
  Future<String> creerCompteParAdmin({
    required String email,
    required String password,
    required UserRole role,
    required String nom,
    required String prenom,
    required String centreId,
  }) async {
    final appSecondaire = await Firebase.initializeApp(
      name: 'creation-${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    try {
      final authSecondaire = FirebaseAuth.instanceFor(app: appSecondaire);
      final credential = await authSecondaire.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;

      final user = UserModel(
        id: uid,
        nom: nom,
        prenom: prenom,
        email: email,
        role: role,
        centreId: centreId,
        isFirstLogin: true,
      );

      try {
        await firestore.collection('users').doc(uid).set(user.toJson());
      } catch (_) {
        // Pas de profil = compte inutilisable : on le supprime plutôt que
        // de laisser un compte orphelin qui bloquerait l'e-mail.
        await credential.user!.delete();
        rethrow;
      }

      await authSecondaire.signOut();
      return uid;
    } finally {
      await appSecondaire.delete();
    }
  }

  /// Inscription d'un admin avec un code d'invitation à usage unique. Le
  /// profil et la consommation du code sont écrits dans un même batch : les
  /// règles Firestore refusent le profil admin si le code n'est pas
  /// consommé par ce même batch.
  Future<void> inscriptionAdmin({
    required String email,
    required String password,
    required String nom,
    required String prenom,
    required String invitationToken,
  }) async {
    final token = invitationToken.trim();
    if (!RegExp(r'^[A-Za-z0-9-]{8,64}$').hasMatch(token)) {
      throw Exception('invitation_invalide');
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    try {
      final invitationRef = firestore.collection('invitations').doc(token);
      final invitation = await invitationRef.get();
      if (!invitation.exists || invitation.data()?['utilise'] == true) {
        throw Exception('invitation_invalide');
      }

      final user = UserModel(
        id: uid,
        nom: nom,
        prenom: prenom,
        // L'e-mail normalisé par Firebase : les règles le comparent au jeton.
        email: credential.user!.email ?? email,
        role: UserRole.admin,
        centreId: '',
        isFirstLogin: false,
      );

      final batch = firestore.batch();
      batch.set(firestore.collection('users').doc(uid), {
        ...user.toJson(),
        'invitation_token': token,
      });
      batch.update(invitationRef, {'utilise': true, 'admin_id': uid});
      await batch.commit();
    } catch (_) {
      await credential.user!.delete();
      rethrow;
    }
  }

  Future<void> changerMotDePasse(String nouveauMotDePasse) async {
    await _auth.currentUser!.updatePassword(nouveauMotDePasse);
  }

  Future<void> reinitialiserMotDePasse(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> deconnexion() => _auth.signOut();
}
