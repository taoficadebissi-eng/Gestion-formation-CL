import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/confirm_logout_dialog.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_admin_provider.dart';
import '../../providers/user_provider.dart';
import 'admin_chat_screen.dart';

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

/// Onglet "Messages" de l'admin (Phase 6) : liste des conversations avec
/// les apprenants ayant déjà échangé.
class AdminConversationsScreen extends ConsumerWidget {
  const AdminConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider).value;
    final conversationsAsync = ref.watch(conversationsAdminProvider);
    final utilisateurs = ref.watch(utilisateursDuCentreProvider).value ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se deconnecter',
            onPressed: () async {
              final confirmer = await showDialog<bool>(
                context: context,
                builder: (_) => const ConfirmLogoutDialog(),
              );
              if (confirmer == true && context.mounted) {
                await ref.read(authNotifierProvider.notifier).deconnexion();
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune conversation pour le moment',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final autreUid = conversation.participants.firstWhere(
                (uid) => uid != userProfile?.id,
                orElse: () => '',
              );
              final autreUser = utilisateurs.where((u) => u.id == autreUid).firstOrNull;
              final nom = autreUser != null ? '${autreUser.prenom} ${autreUser.nom}' : 'Apprenant';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.roleApprenant,
                    child: Icon(Icons.person_rounded, color: Colors.white),
                  ),
                  title: Text(nom, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    conversation.dernierMessage ?? 'Aucun message',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(_formatDate(conversation.dateMaj), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdminChatScreen(
                          conversationId: conversation.id,
                          titre: nom,
                          userId: userProfile!.id,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
