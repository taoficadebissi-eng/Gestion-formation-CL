import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

/// Incrémenté après chaque vérification d'e-mail réussie : `User` ne notifie
/// pas ce changement, les providers et le routeur écoutent ce compteur.
final verificationTickProvider = StateProvider<int>((ref) => 0);

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;

  final Ref _ref;

  AuthNotifier(this._authService, this._ref)
    : super(const AsyncValue.data(null));

  /// Recharge l'utilisateur ; renvoie true si son e-mail est vérifié.
  Future<bool> verifierEmail() async {
    final verifie = await _authService.verifierEmail();
    if (verifie) _ref.read(verificationTickProvider.notifier).state++;
    return verifie;
  }

  Future<void> renvoyerVerificationEmail() =>
      _authService.envoyerVerificationEmail();


  Future<void> connexion(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _authService.connexion(email, password);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<String?> creerCompteParAdmin({
    required String email,
    required String password,
    required UserRole role,
    required String nom,
    required String prenom,
    required String centreId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _authService.creerCompteParAdmin(
        email: email,
        password: password,
        role: role,
        nom: nom,
        prenom: prenom,
        centreId: centreId,
      );
      state = const AsyncValue.data(null);
      return response;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> inscriptionAdmin({
    required String email,
    required String password,
    required String nom,
    required String prenom,
    required String invitationToken,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authService.inscriptionAdmin(
        email: email,
        password: password,
        nom: nom,
        prenom: prenom,
        invitationToken: invitationToken,
      );
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> changerMotDePasse(String nouveauMotDePasse) async {
    state = const AsyncValue.loading();
    try {
      await _authService.changerMotDePasse(nouveauMotDePasse);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> reinitialiserMotDePasse(String email) async {
    state = const AsyncValue.loading();
    try {
      await _authService.reinitialiserMotDePasse(email);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> deconnexion() async {
    await _authService.deconnexion();
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
      return AuthNotifier(ref.watch(authServiceProvider), ref);
    });
