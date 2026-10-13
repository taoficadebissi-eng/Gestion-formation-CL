import '../core/firebase/firestore_helpers.dart';
import '../models/centre_model.dart';

class CentreService {
  final _col = firestore.collection('centres');

  Stream<List<CentreModel>> ecouterCentresAdmin(String adminId) {
    return _col
        .where('admin_id', isEqualTo: adminId)
        .snapshots()
        .map((s) => s.toJsonListe().map(CentreModel.fromJson).toList());
  }

  Stream<CentreModel?> ecouterCentre(String centreId) {
    return _col.doc(centreId).snapshots().map((doc) {
      final json = doc.toJsonAvecId();
      return json == null ? null : CentreModel.fromJson(json);
    });
  }

  Future<String> creerCentre(CentreModel centre) async {
    final ref = await _col.add(centre.toJson());
    return ref.id;
  }

  Future<void> modifierCentre(CentreModel centre) async {
    await _col.doc(centre.id).update(centre.toJson());
  }

  Future<void> desactiverCentre(String id) async {
    await _col.doc(id).update({'actif': false});
  }

  Future<void> supprimerCentre(String id) async {
    await _col.doc(id).delete();
  }
}
