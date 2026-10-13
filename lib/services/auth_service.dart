import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/firebase/firestore_helpers.dart';
import '../models/user_model.dart';

class AuthService {
  static const _cleInscriptionEnAttente = 'inscription_admin_en_attente';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get utilisateurActuel => _auth.currentUser;

  Future<UserCredential> connexion(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user?.emailVerified == true) {
      // Reprend une inscription admin commencée avant la vérification de
      // l'e-mail (ex: lien ouvert depuis un autre appareil).
      try {
        await finaliserInscriptionAdminSiNecessaire();
      } catch (_) {}
    }
    return credential;
  }

  /// Envoie (ou renvoie) l'e-mail de vérification à l'utilisateur connecté.
  Future<void> envoyerVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Recharge l'utilisateur depuis Firebase et indique si son e-mail est
  /// vérifié. Le jeton est rafraîchi pour que les règles Firestore voient
  /// `email_verified == true`, puis une éventuelle inscription admin en
  /// attente est finalisée.
  Future<bool> verifierEmail() async {
    final utilisateur = _auth.currentUser;
    if (utilisateur == null) return false;
    await utilisateur.reload();
    final actuel = _auth.currentUser;
    if (actuel == null || !actuel.emailVerified) return false;
    await actuel.getIdToken(true);
    await finaliserInscriptionAdminSiNecessaire();
    return true;
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

      // Le nouvel utilisateur devra vérifier son e-mail à sa première
      // connexion ; un échec d'envoi n'annule pas la création du compte
      // (l'écran de vérification permet de renvoyer l'e-mail).
      try {
        await credential.user!.sendEmailVerification();
      } catch (_) {}

      await authSecondaire.signOut();
      return uid;
    } finally {
      await appSecondaire.delete();
    }
  }

  /// Inscription d'un admin avec un code d'invitation à usage unique, en
  /// deux temps :
  ///  1. création du compte + envoi de l'e-mail de vérification (le code est
  ///     seulement contrôlé, pas consommé) ;
  ///  2. une fois l'e-mail vérifié, [finaliserInscriptionAdminSiNecessaire]
  ///     écrit le profil et consomme le code dans un même batch (les règles
  ///     Firestore refusent le profil admin si le code n'est pas consommé par
  ///     ce même batch, et exigent un e-mail vérifié).
  /// Une faute de frappe dans l'e-mail ne brûle donc pas le code.
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
    try {
      final invitation = await firestore
          .collection('invitations')
          .doc(token)
          .get();
      if (!invitation.exists || invitation.data()?['utilise'] == true) {
        throw Exception('invitation_invalide');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cleInscriptionEnAttente,
        jsonEncode({
          'uid': credential.user!.uid,
          'nom': nom,
          'prenom': prenom,
          'token': token,
        }),
      );
      await credential.user!.sendEmailVerification();
    } catch (_) {
      await credential.user!.delete();
      rethrow;
    }
  }

  /// Termine l'inscription admin mémorisée par [inscriptionAdmin], si elle
  /// concerne l'utilisateur connecté et que son e-mail est vérifié.
  Future<void> finaliserInscriptionAdminSiNecessaire() async {
    final utilisateur = _auth.currentUser;
    if (utilisateur == null || !utilisateur.emailVerified) return;

    final prefs = await SharedPreferences.getInstance();
    final brut = prefs.getString(_cleInscriptionEnAttente);
    if (brut == null) return;
    final attente = jsonDecode(brut) as Map<String, dynamic>;
    if (attente['uid'] != utilisateur.uid) return;

    final profilRef = firestore.collection('users').doc(utilisateur.uid);
    if ((await profilRef.get()).exists) {
      await prefs.remove(_cleInscriptionEnAttente);
      return;
    }

    final token = attente['token'] as String;
    final invitationRef = firestore.collection('invitations').doc(token);
    final invitation = await invitationRef.get();
    if (!invitation.exists || invitation.data()?['utilise'] == true) {
      await prefs.remove(_cleInscriptionEnAttente);
      throw Exception('invitation_invalide');
    }

    final user = UserModel(
      id: utilisateur.uid,
      nom: attente['nom'] as String,
      prenom: attente['prenom'] as String,
      // L'e-mail normalisé par Firebase : les règles le comparent au jeton.
      email: utilisateur.email ?? '',
      role: UserRole.admin,
      centreId: '',
      isFirstLogin: false,
    );

    final batch = firestore.batch();
    batch.set(profilRef, {...user.toJson(), 'invitation_token': token});
    batch.update(invitationRef, {'utilise': true, 'admin_id': utilisateur.uid});
    await batch.commit();
    await prefs.remove(_cleInscriptionEnAttente);
  }

  Future<void> changerMotDePasse(String nouveauMotDePasse) async {
    await _auth.currentUser!.updatePassword(nouveauMotDePasse);
  }

  Future<void> reinitialiserMotDePasse(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> deconnexion() => _auth.signOut();
}
