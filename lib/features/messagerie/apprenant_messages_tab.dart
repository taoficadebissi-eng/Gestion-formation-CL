import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/centre_provider.dart';
import '../../providers/message_admin_provider.dart';
import '../../providers/user_provider.dart';
import 'admin_chat_screen.dart';

/// Onglet "Messages" de l'apprenant (Phase 6) : conversation unique avec
/// l'admin du centre, créée à la volée au premier message.
class ApprenantMessagesTab extends ConsumerWidget {
  const ApprenantMessagesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider).value;
    final centreAsync = ref.watch(centreActuelProvider);

    return centreAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur : $e'))),
      data: (centre) {
        if (userProfile == null || centre == null) {
          return const Scaffold(body: Center(child: Text('Profil ou centre introuvable')));
        }
        return FutureBuilder(
          future: ref.read(messageAdminServiceProvider).trouverOuCreerConversation(
                centreId: centre.id,
                apprenantId: userProfile.id,
                adminId: centre.adminId,
              ),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Scaffold(
                backgroundColor: AppColors.background,
                body: Center(child: Text('Erreur : ${snapshot.error}')),
              );
            }
            return AdminChatScreen(
              conversationId: snapshot.data!.id,
              titre: 'Messages — ${centre.nom}',
              userId: userProfile.id,
            );
          },
        );
      },
    );
  }
}
