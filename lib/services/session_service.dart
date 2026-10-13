import '../core/firebase/firestore_helpers.dart';
import '../models/session_model.dart';

class SessionService {
  final _col = firestore.collection('sessions');

  List<SessionModel> _trier(List<Map<String, dynamic>> rows) {
    final sessions = rows.map(SessionModel.fromJson).toList();
    sessions.sort((a, b) => a.date.compareTo(b.date));
    return sessions;
  }

  // centre_id est toujours inclus dans la requête : c'est ce qui permet aux
  // règles Firestore de valider l'accès sans lire chaque document.
  Stream<List<SessionModel>> ecouterSessions(
    String formationId,
    String centreId,
  ) {
    return _col
        .where('centre_id', isEqualTo: centreId)
        .where('formation_id', isEqualTo: formationId)
        .snapshots()
        .map((s) => _trier(s.toJsonListe()));
  }

  Stream<List<SessionModel>> ecouterSessionsCentre(String centreId) {
    return _col
        .where('centre_id', isEqualTo: centreId)
        .snapshots()
        .map((s) => _trier(s.toJsonListe()));
  }

  Future<void> ajouterSession(SessionModel session) async {
    await _col.add(session.toJson());
  }

  Future<void> modifierSession(SessionModel session) async {
    await _col.doc(session.id).update(session.toJson());
  }

  Future<void> supprimerSession(String id) async {
    await _col.doc(id).delete();
  }
}
