import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/presence_model.dart';
import '../../models/session_model.dart';
import '../../providers/inscription_provider.dart';
import '../../providers/presence_provider.dart';
import '../../widgets/blurred_toast.dart';

class FeuillePresenceScreen extends ConsumerWidget {
  final SessionModel session;

  const FeuillePresenceScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inscriptionsAsync = ref.watch(
      inscriptionsFormationProvider(session.formationId),
    );
    final presencesAsync = ref.watch(presencesSessionProvider(session.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Feuille de presence'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: inscriptionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (inscriptions) {
            if (inscriptions.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Aucun apprenant inscrit',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }
            return presencesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur : $e')),
              data: (presences) =>
                  _buildListe(context, ref, inscriptions, presences),
            );
          },
        ),
      ),
    );
  }

  Widget _buildListe(
    BuildContext context,
    WidgetRef ref,
    List inscriptions,
    List presences,
  ) {
    final nbPresents = presences.where((p) => p.present).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.titre.isEmpty ? 'Session' : session.titre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${session.heureDebut} a ${session.heureFin}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$nbPresents/${inscriptions.length}',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${inscriptions.length} apprenant(s)',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: inscriptions.length,
            itemBuilder: (context, index) {
              final inscription = inscriptions[index];
              final presence = presences
                  .where((p) => p.apprenantId == inscription.apprenantId)
                  .firstOrNull;
              final estPresent = presence?.present ?? false;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: AppTheme.softCard(radius: 16).copyWith(
                  border: estPresent
                      ? Border.all(color: AppColors.success, width: 1.6)
                      : null,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: estPresent
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.textSecondary.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.person_rounded,
                      color: estPresent
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                  title: Text(
                    inscription.apprenantNom,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  trailing: Switch(
                    value: estPresent,
                    activeThumbColor: AppColors.success,
                    onChanged: (val) async {
                      final nouvellePresence = PresenceModel(
                        id: presence?.id ?? '',
                        sessionId: session.id,
                        formationId: session.formationId,
                        centreId: session.centreId,
                        apprenantId: inscription.apprenantId,
                        apprenantNom: inscription.apprenantNom,
                        present: val,
                        date: session.date,
                      );
                      try {
                        await ref
                            .read(presenceNotifierProvider.notifier)
                            .enregistrer(nouvellePresence);
                      } catch (e) {
                        if (context.mounted) {
                          BlurredToast.show(
                            context,
                            'Erreur : impossible d enregistrer la presence ($e)',
                            icon: Icons.error_outline,
                          );
                        }
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
