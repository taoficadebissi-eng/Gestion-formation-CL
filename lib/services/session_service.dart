import '../core/supabase/supabase_config.dart';
import '../models/session_model.dart';

class SessionService {
  final _db = SupabaseConfig.client;

  // Le stream realtime n'accepte qu'un seul .eq() côté serveur : on filtre
  // sur centreId puis on affine côté client (voir inscription_service.dart).
  Stream<List<SessionModel>> ecouterSessions(
    String formationId,
    String centreId,
  ) {
    return _db
        .from('sessions')
        .stream(primaryKey: ['id'])
        .eq('centre_id', centreId)
        .map((rows) {
          final sessions = rows
              .where((row) => row['formation_id'] == formationId)
              .map(SessionModel.fromJson)
              .toList();
          sessions.sort((a, b) => a.date.compareTo(b.date));
          return sessions;
        });
  }

  Stream<List<SessionModel>> ecouterSessionsCentre(String centreId) {
    return _db
        .from('sessions')
        .stream(primaryKey: ['id'])
        .eq('centre_id', centreId)
        .map((rows) {
          final sessions = rows.map(SessionModel.fromJson).toList();
          sessions.sort((a, b) => a.date.compareTo(b.date));
          return sessions;
        });
  }

  Future<void> ajouterSession(SessionModel session) async {
    await _db.from('sessions').insert(session.toJson());
  }

  Future<void> modifierSession(SessionModel session) async {
    await _db.from('sessions').update(session.toJson()).eq('id', session.id);
  }

  Future<void> supprimerSession(String id) async {
    await _db.from('sessions').delete().eq('id', id);
  }
}
