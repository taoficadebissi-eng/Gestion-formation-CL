import '../core/firebase/firestore_helpers.dart';
import '../models/presence_model.dart';

class PresenceService {
  final _col = firestore.collection('presences');

  /// Une présence par (session, apprenant) : l'id déterministe évite les
  /// doublons sans requête préalable.
  static String idPresence(String sessionId, String apprenantId) =>
      '${sessionId}_$apprenantId';

  Stream<List<PresenceModel>> ecouterPresences(
    String sessionId,
    String centreId,
  ) {
    return _col
        .where('centre_id', isEqualTo: centreId)
        .where('session_id', isEqualTo: sessionId)
        .snapshots()
        .map((s) => s.toJsonListe().map(PresenceModel.fromJson).toList());
  }

  Future<void> enregistrerPresence(PresenceModel presence) async {
    await _col
        .doc(idPresence(presence.sessionId, presence.apprenantId))
        .set(presence.toJson());
  }

  Stream<List<PresenceModel>> ecouterPresencesApprenant(
    String apprenantId,
    String formationId,
    String centreId,
  ) {
    return _col
        .where('centre_id', isEqualTo: centreId)
        .where('apprenant_id', isEqualTo: apprenantId)
        .where('formation_id', isEqualTo: formationId)
        .snapshots()
        .map((s) => s.toJsonListe().map(PresenceModel.fromJson).toList());
  }
}
