import '../core/firebase/firestore_helpers.dart';
import '../models/paiement_model.dart';

class PaiementService {
  final _col = firestore.collection('paiements');

  Stream<List<PaiementModel>> ecouterPaiements(String inscriptionId) {
    return _col
        .where('inscription_id', isEqualTo: inscriptionId)
        .snapshots()
        .map((s) {
          final liste = s.toJsonListe().map(PaiementModel.fromJson).toList();
          liste.sort((a, b) => b.date.compareTo(a.date));
          return liste;
        });
  }
}
