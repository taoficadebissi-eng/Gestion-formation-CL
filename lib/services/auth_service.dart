import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase/supabase_config.dart';
import '../models/user_model.dart';

class AuthService {
  final SupabaseClient _auth = SupabaseConfig.client;

  Stream<Session?> get authStateChanges =>
      _auth.auth.onAuthStateChange.map((state) => state.session);

  Future<AuthResponse> connexion(String email, String password) async {
    return await _auth.auth.signInWithPassword(email: email, password: password);
  }

  /// Crée un compte formateur/apprenant via un client Supabase secondaire,
  /// isolé de la session admin en cours. L'admin reste connecté du début à
  /// la fin : aucune déconnexion/reconnexion, donc aucun risque de flash
  /// vers un écran destiné au nouvel utilisateur.
  Future<AuthResponse> creerCompteParAdmin({
    required String email,
    required String password,
    required UserRole role,
    required String nom,
    required String prenom,
    required String centreId,
  }) async {
    final secondaryClient = SupabaseConfig.createSecondaryClient();

    try {
      final response = await secondaryClient.auth.signUp(
        email: email,
        password: password,
      );

      final user = UserModel(
        id: response.user!.id,
        nom: nom,
        prenom: prenom,
        email: email,
        role: role,
        centreId: centreId,
        isFirstLogin: true,
      );

      await secondaryClient.from('profiles').insert(user.toJson());

      return response;
    } finally {
      // Nettoyage : le client secondaire n'est jamais persisté (pas de
      // LocalStorage configuré, authFlowType: implicit, autoRefreshToken
      // désactivé) : il suffit de le jeter, sans appeler signOut() dessus.
      // (Constaté empiriquement : sur le client principal Flutter, un
      // signOut() effectué sur ce client secondaire finissait par déclencher
      // la suppression de la session admin persistée dans localStorage —
      // dispose() seul est sûr et suffisant ici.)
      secondaryClient.dispose();
    }
  }

  Future<AuthResponse> inscriptionAdmin({
    required String email,
    required String password,
    required String nom,
    required String prenom,
    required String invitationToken,
  }) async {
    final tokenRows = await _auth
        .from('invitations')
        .select()
        .eq('token', invitationToken)
        .eq('utilise', false);

    if (tokenRows.isEmpty) {
      throw Exception('invitation_invalide');
    }

    final response = await _auth.auth.signUp(email: email, password: password);

    final user = UserModel(
      id: response.user!.id,
      nom: nom,
      prenom: prenom,
      email: email,
      role: UserRole.admin,
      centreId: '',
      isFirstLogin: false,
    );

    await _auth.from('profiles').insert(user.toJson());

    await _auth
        .from('invitations')
        .update({'utilise': true, 'admin_id': response.user!.id})
        .eq('id', tokenRows.first['id']);

    return response;
  }

  Future<void> changerMotDePasse(String nouveauMotDePasse) async {
    await _auth.auth.updateUser(UserAttributes(password: nouveauMotDePasse));
  }

  Future<void> reinitialiserMotDePasse(String email) async {
    await _auth.auth.resetPasswordForEmail(email);
  }

  Future<void> deconnexion() async {
    await _auth.auth.signOut();
  }

  User? get utilisateurActuel => _auth.auth.currentUser;
}
