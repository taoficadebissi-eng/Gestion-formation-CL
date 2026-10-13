import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/confirm_logout_dialog.dart';
import '../../models/session_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/centre_provider.dart';
import '../../providers/formation_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/user_provider.dart';

/// Onglet "Accueil" du formateur : sessions du jour et sessions à venir,
/// toutes formations confondues (voir Phase 1 du cahier des charges).
class AccueilFormateurScreen extends ConsumerWidget {
  const AccueilFormateurScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider).value;
    final nomComplet = userProfile != null
        ? '${userProfile.prenom} ${userProfile.nom}'
        : 'Formateur';

    final centreAsync = ref.watch(centreActuelProvider);
    final nomCentre = centreAsync.when(
      data: (centre) => centre?.nom ?? 'Centre',
      loading: () => 'Chargement...',
      error: (_, _) => 'Centre',
    );

    final formations = ref.watch(formationsProvider).value ?? [];
    final mesFormationsIds = formations
        .where((f) => f.formateurId == userProfile?.id)
        .map((f) => f.id)
        .toSet();

    final sessionsAsync = ref.watch(sessionsCentreProvider);

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
        title: const Text('Accueil', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
            tooltip: 'Calendrier des sessions',
            onPressed: () => context.push('/calendrier'),
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
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (toutesSessions) {
          final mesSessions =
              toutesSessions
                  .where((s) => mesFormationsIds.contains(s.formationId))
                  .toList()
                ..sort((a, b) => a.date.compareTo(b.date));

          final now = DateTime.now();
          final aujourdhui = mesSessions
              .where(
                (s) =>
                    s.date.year == now.year &&
                    s.date.month == now.month &&
                    s.date.day == now.day,
              )
              .toList();
          final aVenir = mesSessions
              .where(
                (s) => s.date.isAfter(
                  DateTime(now.year, now.month, now.day, 23, 59, 59),
                ),
              )
              .toList();

          return SingleChildScrollView(
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
                const SizedBox(height: 24),
                _SectionTitre(titre: "Aujourd'hui", count: aujourdhui.length),
                const SizedBox(height: 12),
                if (aujourdhui.isEmpty)
                  const _EtatVide(message: "Aucune session aujourd'hui")
                else
                  ...aujourdhui.map(
                    (s) => _SessionCard(
                      session: s,
                      formations: formations,
                      misEnAvant: true,
                    ),
                  ),
                const SizedBox(height: 24),
                _SectionTitre(titre: 'À venir', count: aVenir.length),
                const SizedBox(height: 12),
                if (aVenir.isEmpty)
                  const _EtatVide(message: 'Aucune session à venir')
                else
                  ...aVenir
                      .take(10)
                      .map(
                        (s) => _SessionCard(
                          session: s,
                          formations: formations,
                          misEnAvant: false,
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitre extends StatelessWidget {
  final String titre;
  final int count;
  const _SectionTitre({required this.titre, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          titre,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _EtatVide extends StatelessWidget {
  final String message;
  const _EtatVide({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.softCard(radius: 16),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionModel session;
  final List formations;
  final bool misEnAvant;

  const _SessionCard({
    required this.session,
    required this.formations,
    required this.misEnAvant,
  });

  @override
  Widget build(BuildContext context) {
    final formation = formations
        .where((f) => f.id == session.formationId)
        .firstOrNull;

    return GestureDetector(
      onTap: () => context.go('/formations/${session.formationId}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.softCard(radius: 16).copyWith(
          border: misEnAvant
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formation?.titre ?? session.titre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session.date.day}/${session.date.month}/${session.date.year} — ${session.heureDebut} à ${session.heureFin}'
                    '${session.salle.isNotEmpty ? ' — ${session.salle}' : ''}',
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
      ),
    );
  }
}
