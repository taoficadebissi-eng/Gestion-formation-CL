import '../core/supabase/supabase_config.dart';
import '../models/message_model.dart';

/// Chat de groupe par formation (Phase 6).
class MessageService {
  final _db = SupabaseConfig.client;

  Stream<List<MessageModel>> ecouterMessages(String formationId) {
    return _db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('formation_id', formationId)
        .order('date_envoi')
        .map((rows) => rows.map(MessageModel.fromJson).toList());
  }

  Future<void> envoyer(MessageModel message) async {
    await _db.from('messages').insert(message.toJson());
  }
}
