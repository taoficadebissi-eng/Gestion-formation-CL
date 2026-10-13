import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inscription_model.dart';
import '../services/inscription_service.dart';
import '../providers/formation_provider.dart'; // pour centreIdEffectifProvider

final inscriptionServiceProvider = Provider<InscriptionService>(
  (ref) => InscriptionService(),
);

final inscriptionsFormationProvider =
    StreamProvider.family<List<InscriptionModel>, String>((ref, formationId) {
      final centreIdAsync = ref.watch(centreIdEffectifProvider);
      return centreIdAsync.when(
        data: (centreId) {
          if (centreId == null || centreId.isEmpty) return Stream.value([]);
          return ref
              .watch(inscriptionServiceProvider)
              .ecouterInscriptionsFormation(formationId, centreId);
        },
        loading: () => Stream.value([]),
        error: (_, _) => Stream.value([]),
      );
    });

final inscriptionsApprenantProvider =
    StreamProvider.family<List<InscriptionModel>, String>((ref, apprenantId) {
      return ref
          .watch(inscriptionServiceProvider)
          .ecouterInscriptionsApprenant(apprenantId);
    });

class InscriptionNotifier extends StateNotifier<AsyncValue<void>> {
  final InscriptionService _service;
  final Ref _ref;

  InscriptionNotifier(this._service, this._ref)
    : super(const AsyncValue.data(null));

  Future<void> inscrire(InscriptionModel inscription) async {
    state = const AsyncValue.loading();
    try {
      final centreId = await _ref.read(centreIdEffectifProvider.future);
      if (centreId == null || centreId.isEmpty) {
        throw Exception('Aucun centre disponible. Inscription impossible.');
      }
      final inscriptionCorrigee = inscription.copyWith(centreId: centreId);
      await _service.inscrire(inscriptionCorrigee);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> modifier(InscriptionModel inscription) async {
    state = const AsyncValue.loading();
    try {
      final centreId = await _ref.read(centreIdEffectifProvider.future);
      if (centreId == null || centreId.isEmpty) {
        throw Exception('Aucun centre disponible. Modification impossible.');
      }
      final inscriptionCorrigee = inscription.copyWith(centreId: centreId);
      await _service.modifier(inscriptionCorrigee);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> annuler(String id) async {
    state = const AsyncValue.loading();
    try {
      await _service.annuler(id);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> enregistrerPaiement({
    required String inscriptionId,
    required double montant,
    String methode = 'manuel',
    String reference = '',
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.enregistrerPaiement(
        inscriptionId: inscriptionId,
        montant: montant,
        methode: methode,
        reference: reference,
      );
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> togglerBlocage(String inscriptionId, bool bloquer) async {
    state = const AsyncValue.loading();
    try {
      await _service.togglerBlocage(inscriptionId, bloquer);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }
}

final inscriptionNotifierProvider =
    StateNotifierProvider<InscriptionNotifier, AsyncValue<void>>((ref) {
      return InscriptionNotifier(ref.watch(inscriptionServiceProvider), ref);
    });
