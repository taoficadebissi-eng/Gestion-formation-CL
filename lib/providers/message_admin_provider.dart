import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation_admin_model.dart';
import '../services/message_admin_service.dart';
import '../services/lecture_tracker.dart';
import 'centre_provider.dart';
import 'user_provider.dart';

final messageAdminServiceProvider = Provider<MessageAdminService>(
  (ref) => MessageAdminService(),
);

final conversationsAdminProvider =
    StreamProvider<List<ConversationAdminModel>>((ref) {
      return ref.watch(messageAdminServiceProvider).ecouterConversations();
    });

final messagesConversationProvider = StreamProvider.family((ref, String conversationId) {
  return ref.watch(messageAdminServiceProvider).ecouterMessages(conversationId);
});

/// Badge "non lu" (Phase 6) pour l'onglet Messages de l'apprenant.
final apprenantMessagesNonLusProvider = FutureProvider.autoDispose<bool>((ref) async {
  final userProfile = ref.watch(userProfileProvider).value;
  final centre = ref.watch(centreActuelProvider).value;
  if (userProfile == null || centre == null) return false;

  final conversation = await ref.read(messageAdminServiceProvider).chercherConversation(
        centreId: centre.id,
        apprenantId: userProfile.id,
        adminId: centre.adminId,
      );
  if (conversation == null || conversation.dernierMessage == null) return false;
  return LectureTracker.estNonLu('conversation_${conversation.id}', conversation.dateMaj);
});

/// Badge "non lu" (Phase 6) pour l'onglet Messages de l'admin : vrai si au
/// moins une conversation a un message plus récent que la dernière lecture.
final adminMessagesNonLusProvider = FutureProvider.autoDispose<bool>((ref) async {
  final conversations = ref.watch(conversationsAdminProvider).value ?? [];
  for (final c in conversations) {
    if (c.dernierMessage == null) continue;
    if (await LectureTracker.estNonLu('conversation_${c.id}', c.dateMaj)) {
      return true;
    }
  }
  return false;
});
