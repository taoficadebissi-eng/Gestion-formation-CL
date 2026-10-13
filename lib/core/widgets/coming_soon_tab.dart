import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../widgets/confirm_logout_dialog.dart';
import '../../providers/auth_provider.dart';

/// Contenu d'onglet temporaire pour les fonctionnalités pas encore
/// implémentées (Messages tant que la Phase 6 n'est pas faite, Paiements
/// tant que la Phase 5 n'est pas faite).
class ComingSoonTab extends ConsumerWidget {
  final String titre;
  final IconData icone;
  final String message;

  const ComingSoonTab({
    super.key,
    required this.titre,
    required this.icone,
    required this.message,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(titre),
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icone,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
