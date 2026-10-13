import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/formation_model.dart';
import '../models/user_model.dart';
import '../services/formation_service.dart';
import 'user_provider.dart';

final formationServiceProvider = Provider<FormationService>(
  (ref) => FormationService(),
);

// Résout le centreId effectif selon le rôle :
// - formateur/apprenant : centreId du profil
// - admin : centre actif (centreIdActifProvider), pas une requête indépendante
// Ne jamais réimplémenter cette résolution ailleurs (cf. README section 1 :
// "Ne jamais confondre les deux : cause historique de bugs d'invisibilité
// silencieuse de données") — une requête admin->centre séparée de
// centreIdActifProvider peut renvoyer un centre différent du centre
// sélectionné/actif, rendant des données existantes invisibles.
final centreIdEffectifProvider = FutureProvider<String?>((ref) async {
  final profile = ref.watch(userProfileProvider).value;
  if (profile == null) return null;

  if (profile.role == UserRole.admin) {
    final centreId = ref.watch(centreIdActifProvider);
    return centreId.isEmpty ? null : centreId;
  } else {
    return profile.centreId.isEmpty ? null : profile.centreId;
  }
});

// Stream des formations filtré par le centreId effectif
final formationsProvider = StreamProvider<List<Formation>>((ref) {
  final centreIdAsync = ref.watch(centreIdEffectifProvider);

  return centreIdAsync.when(
    data: (centreId) {
      if (centreId == null || centreId.isEmpty) return Stream.value([]);
      return ref.watch(formationServiceProvider).ecouterFormations(centreId);
    },
    loading: () => Stream.value([]),
    error: (_, _) => Stream.value([]),
  );
});

class FormationNotifier extends StateNotifier<AsyncValue<void>> {
  final FormationService _service;
  final Ref _ref;

  FormationNotifier(this._service, this._ref)
    : super(const AsyncValue.data(null));

  Future<Formation> ajouter(Formation formation) async {
    state = const AsyncValue.loading();
    try {
      // Le centreId est déjà correctement défini dans l'écran (profil du
      // formateur ou premier centre de l'admin) — on l'utilise tel quel.
      final creee = await _service.ajouterFormation(formation);
      _ref.invalidate(formationsProvider);
      state = const AsyncValue.data(null);
      return creee;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> modifier(Formation formation) async {
    state = const AsyncValue.loading();
    try {
      await _service.modifierFormation(formation);
      _ref.invalidate(formationsProvider);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> supprimer(String id) async {
    state = const AsyncValue.loading();
    try {
      await _service.supprimerFormation(id);
      _ref.invalidate(formationsProvider);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }
}

final formationNotifierProvider =
    StateNotifierProvider<FormationNotifier, AsyncValue<void>>((ref) {
      return FormationNotifier(ref.watch(formationServiceProvider), ref);
    });
