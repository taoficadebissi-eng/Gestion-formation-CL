import '../core/supabase/supabase_config.dart';
import '../models/conversation_admin_model.dart';

/// Messagerie admin <-> apprenant, 1-a-1 (Phase 6).
class MessageAdminService {
  final _db = SupabaseConfig.client;

  Future<ConversationAdminModel> trouverOuCreerConversation({
    required String centreId,
    required String apprenantId,
    required String adminId,
  }) async {
    final existants = await _db
        .from('messages_admin_conversations')
        .select()
        .eq('centre_id', centreId)
        .contains('participants', [apprenantId, adminId]);

    if (existants.isNotEmpty) {
      return ConversationAdminModel.fromJson(existants.first);
    }

    final cree = await _db
        .from('messages_admin_conversations')
        .insert({
          'centre_id': centreId,
          'participants': [apprenantId, adminId],
          'date_maj': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return ConversationAdminModel.fromJson(cree);
  }

  /// Comme trouverOuCreerConversation, mais ne crée rien : renvoie null si
  /// aucune conversation n'existe encore (utilisé pour le badge "non lu",
  /// pour ne pas créer une conversation vide juste en consultant l'état).
  Future<ConversationAdminModel?> chercherConversation({
    required String centreId,
    required String apprenantId,
    required String adminId,
  }) async {
    final existants = await _db
        .from('messages_admin_conversations')
        .select()
        .eq('centre_id', centreId)
        .contains('participants', [apprenantId, adminId]);
    if (existants.isEmpty) return null;
    return ConversationAdminModel.fromJson(existants.first);
  }

  // Pas de .eq() ici : la policy RLS restreint deja aux conversations dont
  // l'appelant fait partie de `participants`, inutile de refiltrer.
  Stream<List<ConversationAdminModel>> ecouterConversations() {
    return _db
        .from('messages_admin_conversations')
        .stream(primaryKey: ['id'])
        .order('date_maj', ascending: false)
        .map((rows) => rows.map(ConversationAdminModel.fromJson).toList());
  }

  Stream<List<MessageAdminModel>> ecouterMessages(String conversationId) {
    return _db
        .from('messages_admin')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('date_envoi')
        .map((rows) => rows.map(MessageAdminModel.fromJson).toList());
  }

  Future<void> envoyerMessage(MessageAdminModel message) async {
    await _db.from('messages_admin').insert(message.toJson());
    await _db
        .from('messages_admin_conversations')
        .update({
          'dernier_message': message.texte,
          'date_maj': DateTime.now().toIso8601String(),
        })
        .eq('id', message.conversationId);
  }
}
