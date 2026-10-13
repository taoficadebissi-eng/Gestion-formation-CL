import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/blurred_toast.dart';
import '../models/cours_gratuit_model.dart';
import '../providers/cours_admin_provider.dart';

/// Détail d'un cours (espace super-admin) : consultation, modification,
/// suppression.
class DetailCoursAdminScreen extends ConsumerWidget {
  final String coursId;
  const DetailCoursAdminScreen({super.key, required this.coursId});

  Future<void> _supprimer(
    BuildContext context,
    WidgetRef ref,
    CoursGratuit cours,
  ) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce cours ?'),
        content: Text(
          '« ${cours.titre} » disparaitra de la vitrine publique. '
          'Cette action est definitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await ref.read(coursAdminServiceProvider).supprimer(cours.id);
      if (context.mounted) {
        BlurredToast.show(
          context,
          'Cours supprime',
          icon: Icons.delete_outline,
        );
        context.go('/super-admin/cours');
      }
    } catch (e) {
      if (context.mounted) {
        BlurredToast.show(context, 'Erreur : $e', icon: Icons.error_outline);
      }
    }
  }

  Future<void> _ouvrirLien(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok && context.mounted) {
      BlurredToast.show(
        context,
        'Lien impossible a ouvrir',
        icon: Icons.error_outline,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursAsync = ref.watch(coursAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail du cours'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/super-admin/cours'),
        ),
      ),
      body: coursAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (liste) {
          final cours = liste.where((c) => c.id == coursId).firstOrNull;
          if (cours == null) {
            return const Center(child: Text('Ce cours n\'existe plus'));
          }
          final image = cours.lienImage;
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              SizedBox(
                height: 200,
                child: (image != null && image.isNotEmpty)
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _banniereParDefaut(),
                      )
                    : _banniereParDefaut(),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cours.titre,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(cours.fournisseur)),
                        Chip(label: Text(cours.niveau.label)),
                        Chip(label: Text(cours.categorie)),
                        Chip(label: Text(cours.langue)),
                        if (cours.duree != null && cours.duree!.isNotEmpty)
                          Chip(label: Text(cours.duree!)),
                        if (cours.certificatDisponible)
                          Chip(
                            label: Text(
                              cours.certificatPayant
                                  ? 'Certificat payant'
                                  : 'Certificat gratuit',
                            ),
                          ),
                        Chip(
                          label: Text(cours.actif ? 'Visible' : 'Masque'),
                          backgroundColor: cours.actif
                              ? AppColors.accentLight.withValues(alpha: 0.35)
                              : AppColors.surfaceAlt,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Description courte',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(cours.description),
                    const SizedBox(height: 16),
                    const Text(
                      'Description detaillee',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(cours.descriptionDetaillee),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _ouvrirLien(context, cours.lienCours),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Ouvrir le cours'),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => context.go(
                              '/super-admin/cours/${cours.id}/modifier',
                            ),
                            icon: const Icon(Icons.edit),
                            label: const Text('Modifier'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _supprimer(context, ref, cours),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                            ),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Supprimer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _banniereParDefaut() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: AppColors.brandGradient),
      ),
      child: const Center(
        child: Icon(Icons.school_rounded, size: 64, color: Colors.white70),
      ),
    );
  }
}
