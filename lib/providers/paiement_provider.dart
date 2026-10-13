import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/paiement_model.dart';
import '../services/paiement_service.dart';

final paiementServiceProvider = Provider<PaiementService>(
  (ref) => PaiementService(),
);

final paiementsInscriptionProvider =
    StreamProvider.family<List<PaiementModel>, String>((ref, inscriptionId) {
      return ref.watch(paiementServiceProvider).ecouterPaiements(inscriptionId);
    });
