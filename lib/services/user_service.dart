import '../core/firebase/firestore_helpers.dart';
import '../models/user_model.dart';

class UserService {
  final _col = firestore.collection('users');

  Stream<UserModel?> ecouterUtilisateur(String userId) {
    return _col.doc(userId).snapshots().map((doc) {
      final json = doc.toJsonAvecId();
      return json == null ? null : UserModel.fromJson(json);
    });
  }

  Stream<List<UserModel>> ecouterUtilisateursParRole(
    String role,
    String centreId,
  ) {
    return _col
        .where('centre_id', isEqualTo: centreId)
        .where('role', isEqualTo: role)
        .snapshots()
        .map((s) => s.toJsonListe().map(UserModel.fromJson).toList());
  }

  Stream<List<UserModel>> ecouterTousUtilisateurs(String centreId) {
    return _col
        .where('centre_id', isEqualTo: centreId)
        .snapshots()
        .map((s) => s.toJsonListe().map(UserModel.fromJson).toList());
  }

  Future<void> marquerPremierLoginEffectue(String userId) async {
    await _col.doc(userId).update({'is_first_login': false});
  }

  Future<void> marquerMotDePasseChange(String userId) =>
      marquerPremierLoginEffectue(userId);
}
