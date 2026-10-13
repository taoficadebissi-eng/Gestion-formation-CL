import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_model.dart';
import '../services/session_service.dart';
import '../providers/formation_provider.dart'; // pour centreIdEffectifProvider

final sessionServiceProvider = Provider<SessionService>(
  (ref) => SessionService(),
);

final sessionsProvider = StreamProvider.family<List<SessionModel>, String>((
  ref,
  formationId,
) {
  final centreIdAsync = ref.watch(centreIdEffectifProvider);

  return centreIdAsync.when(
    data: (centreId) {
      if (centreId == null || centreId.isEmpty) return Stream.value([]);
      return ref
          .watch(sessionServiceProvider)
          .ecouterSessions(formationId, centreId);
    },
    loading: () => Stream.value([]),
    error: (_, _) => Stream.value([]),
  );
});

// Toutes les sessions du centre (toutes formations confondues), pour la
// vue calendrier mensuelle.
final sessionsCentreProvider = StreamProvider<List<SessionModel>>((ref) {
  final centreIdAsync = ref.watch(centreIdEffectifProvider);

  return centreIdAsync.when(
    data: (centreId) {
      if (centreId == null || centreId.isEmpty) return Stream.value([]);
      return ref
          .watch(sessionServiceProvider)
          .ecouterSessionsCentre(centreId);
    },
    loading: () => Stream.value([]),
    error: (_, _) => Stream.value([]),
  );
});

class SessionNotifier extends StateNotifier<AsyncValue<void>> {
  final SessionService _service;
  final Ref _ref;

  SessionNotifier(this._service, this._ref)
    : super(const AsyncValue.data(null));

  Future<void> ajouter(SessionModel session) async {
    state = const AsyncValue.loading();
    try {
      final centreId = await _ref.read(centreIdEffectifProvider.future);
      if (centreId == null || centreId.isEmpty) {
        throw Exception(
          'Aucun centre disponible. Impossible de créer la session.',
        );
      }
      final sessionCorrigee = session.copyWith(centreId: centreId);
      await _service.ajouterSession(sessionCorrigee);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> modifier(SessionModel session) async {
    state = const AsyncValue.loading();
    try {
      final centreId = await _ref.read(centreIdEffectifProvider.future);
      if (centreId == null || centreId.isEmpty) {
        throw Exception(
          'Aucun centre disponible. Impossible de modifier la session.',
        );
      }
      final sessionCorrigee = session.copyWith(centreId: centreId);
      await _service.modifierSession(sessionCorrigee);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> supprimer(String id) async {
    state = const AsyncValue.loading();
    try {
      await _service.supprimerSession(id);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }
}

final sessionNotifierProvider =
    StateNotifierProvider<SessionNotifier, AsyncValue<void>>((ref) {
      return SessionNotifier(ref.watch(sessionServiceProvider), ref);
    });
