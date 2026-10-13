import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/presence_model.dart';
import '../services/presence_service.dart';
import '../providers/formation_provider.dart'; // pour centreIdEffectifProvider

final presenceServiceProvider = Provider<PresenceService>(
  (ref) => PresenceService(),
);

final presencesSessionProvider =
    StreamProvider.family<List<PresenceModel>, String>((ref, sessionId) {
      final centreIdAsync = ref.watch(centreIdEffectifProvider);
      return centreIdAsync.when(
        data: (centreId) {
          if (centreId == null || centreId.isEmpty) return Stream.value([]);
          return ref
              .watch(presenceServiceProvider)
              .ecouterPresences(sessionId, centreId);
        },
        loading: () => Stream.value([]),
        error: (_, _) => Stream.value([]),
      );
    });

final presencesApprenantProvider =
    StreamProvider.family<List<PresenceModel>, String>((ref, params) {
      final parts = params.split('|');
      final centreIdAsync = ref.watch(centreIdEffectifProvider);
      return centreIdAsync.when(
        data: (centreId) {
          if (centreId == null || centreId.isEmpty) return Stream.value([]);
          return ref
              .watch(presenceServiceProvider)
              .ecouterPresencesApprenant(parts[0], parts[1], centreId);
        },
        loading: () => Stream.value([]),
        error: (_, _) => Stream.value([]),
      );
    });

class PresenceNotifier extends StateNotifier<AsyncValue<void>> {
  final PresenceService _service;
  final Ref _ref;

  PresenceNotifier(this._service, this._ref)
    : super(const AsyncValue.data(null));

  Future<void> enregistrer(PresenceModel presence) async {
    state = const AsyncValue.loading();
    try {
      final centreId = await _ref.read(centreIdEffectifProvider.future);
      if (centreId == null || centreId.isEmpty) {
        throw Exception('Aucun centre disponible. Enregistrement impossible.');
      }
      final presenceCorrigee = presence.copyWith(centreId: centreId);
      await _service.enregistrerPresence(presenceCorrigee);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }
}

final presenceNotifierProvider =
    StateNotifierProvider<PresenceNotifier, AsyncValue<void>>((ref) {
      return PresenceNotifier(ref.watch(presenceServiceProvider), ref);
    });
