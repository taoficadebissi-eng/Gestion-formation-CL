import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../services/lecture_tracker.dart';
import 'formation_provider.dart';
import 'user_provider.dart';

final messageServiceProvider = Provider<MessageService>(
  (ref) => MessageService(),
);

final messagesFormationProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, formationId) {
      return ref.watch(messageServiceProvider).ecouterMessages(formationId);
    });

/// Badge "non lu" (Phase 6) pour l'onglet Messages du formateur : vrai si
/// une de ses formations a un message de groupe plus récent que sa
/// dernière lecture (ses propres messages ne comptent pas).
final formateurMessagesNonLusProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final userProfile = ref.watch(userProfileProvider).value;
  final formations = ref.watch(formationsProvider).value ?? [];
  if (userProfile == null) return false;

  final mesFormations = formations.where(
    (f) => f.formateurId == userProfile.id,
  );
  final service = ref.read(messageServiceProvider);
  for (final formation in mesFormations) {
    final messages = await service.ecouterMessages(formation.id).first;
    if (messages.isEmpty) continue;
    final dernier = messages.last;
    if (dernier.auteurId == userProfile.id) continue;
    if (await LectureTracker.estNonLu(
      'formation_${formation.id}',
      dernier.dateEnvoi,
    )) {
      return true;
    }
  }
  return false;
});
