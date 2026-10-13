import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/centre_model.dart';
import '../models/user_model.dart';
import '../services/centre_service.dart';
import 'user_provider.dart';

final centreServiceProvider = Provider<CentreService>((ref) => CentreService());

final centresDuAdminProvider = StreamProvider<List<CentreModel>>((ref) {
  final userProfile = ref.watch(userProfileProvider).value;
  if (userProfile == null) return Stream.value([]);
  return ref.watch(centreServiceProvider).ecouterCentresAdmin(userProfile.id);
});

final centreActifProvider = StateProvider<CentreModel?>((ref) => null);

final centreActuelProvider = StreamProvider<CentreModel?>((ref) {
  final userProfile = ref.watch(userProfileProvider).value;
  if (userProfile == null) return Stream.value(null);

  if (userProfile.role == UserRole.admin) {
    return ref
        .watch(centresDuAdminProvider)
        .when(
          data: (centres) =>
              Stream.value(centres.isNotEmpty ? centres.first : null),
          loading: () => Stream.value(null),
          error: (_, _) => Stream.value(null),
        );
  }

  final centreId = userProfile.centreId;
  if (centreId.isEmpty) return Stream.value(null);

  return ref.watch(centreServiceProvider).ecouterCentre(centreId);
});

class CentreNotifier extends StateNotifier<AsyncValue<void>> {
  final CentreService _service;
  CentreNotifier(this._service) : super(const AsyncValue.data(null));

  Future<void> creer(CentreModel centre) async {
    state = const AsyncValue.loading();
    try {
      await _service.creerCentre(centre);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> modifier(CentreModel centre) async {
    state = const AsyncValue.loading();
    try {
      await _service.modifierCentre(centre);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> desactiver(String id) async {
    state = const AsyncValue.loading();
    try {
      await _service.desactiverCentre(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> supprimer(String id) async {
    state = const AsyncValue.loading();
    try {
      await _service.supprimerCentre(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final centreNotifierProvider =
    StateNotifierProvider<CentreNotifier, AsyncValue<void>>((ref) {
      return CentreNotifier(ref.watch(centreServiceProvider));
    });
