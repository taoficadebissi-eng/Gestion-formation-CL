import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../models/user_model.dart';
import '../../providers/session_provider.dart';
import '../../providers/user_provider.dart';
import '../suivi/feuille_presence_screen.dart';

class SessionsScreen extends ConsumerWidget {
  final String formationId;
  final String formationTitre;

  const SessionsScreen({
    super.key,
    required this.formationId,
    required this.formationTitre,
  });

  String _formatDate(DateTime date) {
    final jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final mois = [
      'Jan',
      'Fev',
      'Mar',
      'Avr',
      'Mai',
      'Jun',
      'Jul',
      'Aou',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${jours[date.weekday - 1]} ${date.day} ${mois[date.month - 1]} ${date.year}';
  }

  Color _couleurStatut(String statut) {
    if (statut == 'enCours') return AppColors.success;
    if (statut == 'terminee') return AppColors.textSecondary;
    return AppColors.info;
  }

  String _libelleStatut(String statut) {
    if (statut == 'enCours') return 'En cours';
    if (statut == 'terminee') return 'Terminee';
    return 'Planifiee';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider(formationId));
    final userProfile = ref.watch(userProfileProvider).value;
    final peutGerer =
        userProfile?.role == UserRole.admin ||
        userProfile?.role == UserRole.formateur;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary, // Force le fond bleu
        foregroundColor: Colors.white, // Force le texte/icônes en blanc
        elevation: 0, // Optionnel : look plus moderne sans ombr),
        title: Text(formationTitre),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/formations/$formationId'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: sessionsAsync.when(
          loading: () => const SkeletonListLoader(),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (sessions) {
            if (sessions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_busy_rounded,
                      size: 64,
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Aucune session planifiee',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    if (peutGerer) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Appuyez sur + pour ajouter une session',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${sessions.length} session(s)',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final couleur = _couleurStatut(session.statut.name);
                      return GestureDetector(
                        onTap: peutGerer
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FeuillePresenceScreen(session: session),
                                ),
                              )
                            : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: AppTheme.softCard(radius: 18).copyWith(
                            border: peutGerer
                                ? Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                    width: 1.4,
                                  )
                                : null,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: couleur.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.event_rounded,
                                  color: couleur,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (session.titre.isNotEmpty)
                                      Text(
                                        session.titre,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDate(session.date),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${session.heureDebut} - ${session.heureFin}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.room_rounded,
                                          size: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          session.salle,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: couleur.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            _libelleStatut(session.statut.name),
                                            style: TextStyle(
                                              color: couleur,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (session.details.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        session.details,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    if (peutGerer) ...[
                                      const SizedBox(height: 8),
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.checklist_rounded,
                                            size: 14,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Appuyer pour la feuille de presence',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (peutGerer)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_rounded,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () async {
                                    final confirmer = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        title: const Text(
                                          'Supprimer la session',
                                        ),
                                        content: const Text('Etes-vous sur ?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Annuler'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.error,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Supprimer'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmer == true && context.mounted) {
                                      await ref
                                          .read(
                                            sessionNotifierProvider.notifier,
                                          )
                                          .supprimer(session.id);
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: peutGerer
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () =>
                  context.go('/formations/$formationId/sessions/ajouter'),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
