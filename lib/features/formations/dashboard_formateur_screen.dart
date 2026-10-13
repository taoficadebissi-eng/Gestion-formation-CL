import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/confirm_logout_dialog.dart';
import '../../providers/auth_provider.dart';
import '../../providers/formation_provider.dart';
import '../../providers/inscription_provider.dart'; // ✅ Garder pour le StreamProvider
import '../../providers/session_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/centre_provider.dart';

class DashboardFormateurScreen extends ConsumerWidget {
  const DashboardFormateurScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider).value;
    final formations = ref.watch(formationsProvider).value ?? [];
    final nomComplet = userProfile != null
        ? '${userProfile.prenom} ${userProfile.nom}'
        : 'Formateur';
    final mesFormations = formations
        .where((f) => f.formateurId == userProfile?.id)
        .toList();

    final centreAsync = ref.watch(centreActuelProvider);
    final nomCentre = centreAsync.when(
      data: (centre) => centre?.nom ?? 'Centre',
      loading: () => 'Chargement...',
      error: (_, _) => 'Centre',
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.business_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      nomCentre,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        leadingWidth: 140,
        title: const Text('Mon Espace', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
            tooltip: 'Calendrier des sessions',
            onPressed: () => context.push('/calendrier'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                nomComplet,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonjour, $nomComplet !',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${mesFormations.length} formation(s) cree(s)',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Mes formations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (mesFormations.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.book_outlined,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Aucune formation creee',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...mesFormations.map((formation) {
                // ✅ CORRECTION NOM DU PROVIDER
                final inscriptionsAsync = ref.watch(
                  inscriptionsFormationProvider(formation.id),
                );
                final sessionsAsync = ref.watch(sessionsProvider(formation.id));
                final nbInscrits = inscriptionsAsync.value?.length ?? 0;
                final sessions = sessionsAsync.value ?? [];
                final today = DateTime.now();
                final sessionsAujourdhui = sessions
                    .where(
                      (s) =>
                          s.date.year == today.year &&
                          s.date.month == today.month &&
                          s.date.day == today.day,
                    )
                    .length;

                return GestureDetector(
                  onTap: () => context.go('/formations/${formation.id}'),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.book_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formation.titre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    formation.niveau,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _StatMini(
                              icone: Icons.people_rounded,
                              valeur: nbInscrits.toString(),
                              label: 'inscrits',
                              couleur: AppColors.roleApprenant,
                            ),
                            const SizedBox(width: 12),
                            _StatMini(
                              icone: Icons.calendar_today_rounded,
                              valeur: sessions.length.toString(),
                              label: 'sessions',
                              couleur: AppColors.primary,
                            ),
                            if (sessionsAujourdhui > 0) ...[
                              const SizedBox(width: 12),
                              _StatMini(
                                icone: Icons.today_rounded,
                                valeur: sessionsAujourdhui.toString(),
                                label: 'aujourd hui',
                                couleur: AppColors.warning,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.go('/formations'),
              icon: const Icon(Icons.list_rounded),
              label: const Text('Voir toutes les formations'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final IconData icone;
  final String valeur;
  final String label;
  final Color couleur;
  const _StatMini({
    required this.icone,
    required this.valeur,
    required this.label,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icone, size: 14, color: couleur),
          const SizedBox(width: 4),
          Text(
            '$valeur $label',
            style: TextStyle(
              color: couleur,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
