import '../core/supabase/supabase_config.dart';
import '../models/presence_model.dart';

class PresenceService {
  final _db = SupabaseConfig.client;

  // Le stream realtime n'accepte qu'un seul .eq() côté serveur : on filtre
  // sur centreId puis on affine côté client (voir inscription_service.dart).
  Stream<List<PresenceModel>> ecouterPresences(
    String sessionId,
    String centreId,
  ) {
    return _db
        .from('presences')
        .stream(primaryKey: ['id'])
        .eq('centre_id', centreId)
        .map(
          (rows) => rows
              .where((row) => row['session_id'] == sessionId)
              .map(PresenceModel.fromJson)
              .toList(),
        );
  }

  Future<void> enregistrerPresence(PresenceModel presence) async {
    final existing = await _db
        .from('presences')
        .select('id')
        .eq('session_id', presence.sessionId)
        .eq('apprenant_id', presence.apprenantId)
        .eq('centre_id', presence.centreId);
    if (existing.isNotEmpty) {
      await _db
          .from('presences')
          .update({'present': presence.present})
          .eq('id', existing.first['id']);
    } else {
      await _db.from('presences').insert(presence.toJson());
    }
  }

  Stream<List<PresenceModel>> ecouterPresencesApprenant(
    String apprenantId,
    String formationId,
    String centreId,
  ) {
    return _db
        .from('presences')
        .stream(primaryKey: ['id'])
        .eq('centre_id', centreId)
        .map(
          (rows) => rows
              .where(
                (row) =>
                    row['apprenant_id'] == apprenantId &&
                    row['formation_id'] == formationId,
              )
              .map(PresenceModel.fromJson)
              .toList(),
        );
  }
}
