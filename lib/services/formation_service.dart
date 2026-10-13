import '../core/firebase/firestore_helpers.dart';
import '../models/formation_model.dart';

class FormationService {
  final _col = firestore.collection('formations');

  Stream<List<Formation>> ecouterFormations(String centreId) {
    return _col.where('centre_id', isEqualTo: centreId).snapshots().map((s) {
      final liste = s.toJsonListe().map(Formation.fromJson).toList();
      liste.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
      return liste;
    });
  }

  Future<Formation> ajouterFormation(Formation formation) async {
    final ref = await _col.add(formation.toJson());
    return formation.copyWith(id: ref.id);
  }

  Future<void> modifierFormation(Formation formation) async {
    await _col.doc(formation.id).update(formation.toJson());
  }

  Future<void> supprimerFormation(String id) async {
    await _col.doc(id).delete();
  }
}
