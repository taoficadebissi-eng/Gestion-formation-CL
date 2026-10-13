import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'auth_provider.dart';
import 'centre_provider.dart';

final userServiceProvider = Provider<UserService>((ref) => UserService());

final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (Session? session) {
      if (session == null) return Stream.value(null);
      return ref.watch(userServiceProvider).ecouterUtilisateur(session.user.id);
    },
    loading: () => Stream.value(null),
    error: (_, _) => Stream.value(null),
  );
});

// Provider qui retourne le centreId actif sans jamais modifier d'autre provider
final centreIdActifProvider = Provider<String>((ref) {
  final centreActif = ref.watch(centreActifProvider);
  if (centreActif != null) return centreActif.id;

  final centres = ref.watch(centresDuAdminProvider).value;
  if (centres != null && centres.isNotEmpty) {
    return centres.first.id;
  }
  return '';
});

final nombreApprennantsProvider = StreamProvider<int>((ref) {
  final centreId = ref.watch(centreIdActifProvider);
  if (centreId.isEmpty) return Stream.value(0);
  return ref
      .watch(userServiceProvider)
      .ecouterUtilisateursParRole('apprenant', centreId)
      .map((liste) => liste.length);
});

final nombreFormateursProvider = StreamProvider<int>((ref) {
  final centreId = ref.watch(centreIdActifProvider);
  if (centreId.isEmpty) return Stream.value(0);
  return ref
      .watch(userServiceProvider)
      .ecouterUtilisateursParRole('formateur', centreId)
      .map((liste) => liste.length);
});

final utilisateursDuCentreProvider = StreamProvider<List<UserModel>>((ref) {
  final centreId = ref.watch(centreIdActifProvider);
  if (centreId.isEmpty) return Stream.value([]);
  return ref.watch(userServiceProvider).ecouterTousUtilisateurs(centreId);
});

class UserNotifier extends StateNotifier<AsyncValue<void>> {
  final UserService _service;
  UserNotifier(this._service) : super(const AsyncValue.data(null));

  Future<void> marquerPremierLoginEffectue(String uid) async {
    state = const AsyncValue.loading();
    try {
      await _service.marquerPremierLoginEffectue(uid);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }
}

final userNotifierProvider =
    StateNotifierProvider<UserNotifier, AsyncValue<void>>((ref) {
      return UserNotifier(ref.watch(userServiceProvider));
    });
