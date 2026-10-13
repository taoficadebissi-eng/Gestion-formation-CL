import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/confirm_logout_dialog.dart';
import '../../providers/auth_provider.dart';
import '../../providers/formation_provider.dart';
import '../../providers/centre_provider.dart';
import '../../providers/user_provider.dart';
import 'package:go_router/go_router.dart';

/// Onglet "Accueil" de l'admin : résumé du centre (formations, apprenants,
/// formateurs). Les actions (voir formations, gérer utilisateurs) sont
/// désormais dans la bottom navigation — cet onglet reste un résumé, pas une
/// liste de raccourcis qui duplique les autres onglets.
class AccueilAdminTab extends ConsumerWidget {
  const AccueilAdminTab({super.key});

  Future<void> _deconnecter(BuildContext context, WidgetRef ref) async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmLogoutDialog(),
    );
    if (confirmer == true && context.mounted) {
      await ref.read(authNotifierProvider.notifier).deconnexion();
      if (context.mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider).value;
    final formationsAsync = ref.watch(formationsProvider);
    final nombreApprenants = ref.watch(nombreApprennantsProvider).value ?? 0;
    final nombreFormateurs = ref.watch(nombreFormateursProvider).value ?? 0;
    final nomComplet = userProfile != null
        ? '${userProfile.prenom} ${userProfile.nom}'
        : 'Administrateur';
    final nombreFormations = formationsAsync.value?.length ?? 0;

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
                  const Icon(Icons.business_rounded, size: 14, color: Colors.white),
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
            tooltip: 'Se deconnecter',
            onPressed: () => _deconnecter(context, ref),
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
            const Text(
              'Voici le resume du centre de formation',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    titre: 'Formations',
                    valeur: nombreFormations.toString(),
                    icone: Icons.book_rounded,
                    couleur: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    titre: 'Apprenants',
                    valeur: nombreApprenants.toString(),
                    icone: Icons.people_rounded,
                    couleur: AppColors.roleApprenant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatCard(
              titre: 'Formateurs',
              valeur: nombreFormateurs.toString(),
              icone: Icons.person_rounded,
              couleur: AppColors.roleFormateur,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String titre;
  final String valeur;
  final IconData icone;
  final Color couleur;

  const _StatCard({
    required this.titre,
    required this.valeur,
    required this.icone,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.softCard(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icone, color: couleur, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            valeur,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: couleur,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            titre,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
