import 'package:firebase_auth/firebase_auth.dart';
import '../core/firebase/firestore_helpers.dart';
import '../models/conversation_admin_model.dart';

/// Messagerie admin <-> apprenant, 1-a-1.
class MessageAdminService {
  final _conversations = firestore.collection('messages_admin_conversations');
  final _messages = firestore.collection('messages_admin');

  /// Une conversation par (centre, apprenant, admin) : id déterministe.
  static String idConversation(
    String centreId,
    String apprenantId,
    String adminId,
  ) => '${centreId}_${apprenantId}_$adminId';

  Future<ConversationAdminModel> trouverOuCreerConversation({
    required String centreId,
    required String apprenantId,
    required String adminId,
  }) async {
    final ref = _conversations.doc(
      idConversation(centreId, apprenantId, adminId),
    );
    final doc = await ref.get();
    final json = doc.toJsonAvecId();
    if (json != null) return ConversationAdminModel.fromJson(json);

    final conversation = ConversationAdminModel(
      id: ref.id,
      centreId: centreId,
      participants: [apprenantId, adminId],
      dateMaj: DateTime.now(),
    );
    await ref.set(conversation.toJson());
    return conversation;
  }

  /// Comme trouverOuCreerConversation, mais ne crée rien : renvoie null si
  /// aucune conversation n'existe encore (badge "non lu").
  Future<ConversationAdminModel?> chercherConversation({
    required String centreId,
    required String apprenantId,
    required String adminId,
  }) async {
    final doc = await _conversations
        .doc(idConversation(centreId, apprenantId, adminId))
        .get();
    final json = doc.toJsonAvecId();
    return json == null ? null : ConversationAdminModel.fromJson(json);
  }

  Stream<List<ConversationAdminModel>> ecouterConversations() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _conversations
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((s) {
          final liste = s
              .toJsonListe()
              .map(ConversationAdminModel.fromJson)
              .toList();
          liste.sort((a, b) => b.dateMaj.compareTo(a.dateMaj));
          return liste;
        });
  }

  Stream<List<MessageAdminModel>> ecouterMessages(String conversationId) {
    return _messages
        .where('conversation_id', isEqualTo: conversationId)
        .snapshots()
        .map((s) {
          final liste = s
              .toJsonListe()
              .map(MessageAdminModel.fromJson)
              .toList();
          liste.sort((a, b) => a.dateEnvoi.compareTo(b.dateEnvoi));
          return liste;
        });
  }

  Future<void> envoyerMessage(MessageAdminModel message) async {
    final batch = firestore.batch();
    batch.set(_messages.doc(), message.toJson());
    batch.update(_conversations.doc(message.conversationId), {
      'dernier_message': message.texte,
      'date_maj': DateTime.now().toIso8601String(),
    });
    await batch.commit();
  }
}
