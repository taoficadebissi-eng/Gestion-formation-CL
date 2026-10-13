import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/confirm_logout_dialog.dart';
import '../../providers/auth_provider.dart';
import '../../providers/formation_provider.dart';
import '../../providers/inscription_provider.dart';
import '../../providers/user_provider.dart';
import 'package:go_router/go_router.dart';
import 'group_chat_screen.dart';

/// Onglet "Messages" du formateur (Phase 6) : liste de ses formations,
/// chacune ouvrant son chat de groupe.
class FormateurMessagesTab extends ConsumerWidget {
  const FormateurMessagesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider).value;
    final formations = ref.watch(formationsProvider).value ?? [];
    final mesFormations = formations
        .where((f) => f.formateurId == userProfile?.id)
        .toList();

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
      body: mesFormations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 64,
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune formation, aucune discussion de groupe',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: mesFormations.length,
              itemBuilder: (context, index) {
                final formation = mesFormations[index];
                return Consumer(
                  builder: (context, ref, _) {
                    final inscriptions =
                        ref
                            .watch(inscriptionsFormationProvider(formation.id))
                            .value ??
                        [];
                    final nomParUid = <String, String>{
                      formation.formateurId: formation.formateurNom,
                      for (final i in inscriptions)
                        i.apprenantId: i.apprenantNom,
                    };
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.forum_rounded, color: Colors.white),
                        ),
                        title: Text(
                          formation.titre,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${inscriptions.length} participant(s)'),
                        onTap: () {
                          if (userProfile == null) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GroupChatScreen(
                                formationId: formation.id,
                                formationTitre: formation.titre,
                                userId: userProfile.id,
                                nomParUid: nomParUid,
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
