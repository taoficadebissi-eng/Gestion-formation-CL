import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/blurred_toast.dart';
import '../models/proposition_model.dart';
import '../providers/cours_admin_provider.dart';

/// Détail d'une proposition : on lit la fiche, on ouvre le lien pour vérifier
/// que le cours existe vraiment, puis on approuve, on corrige ou on rejette.
class DetailPropositionScreen extends ConsumerStatefulWidget {
  final String propositionId;
  const DetailPropositionScreen({super.key, required this.propositionId});

  @override
  ConsumerState<DetailPropositionScreen> createState() =>
      _DetailPropositionScreenState();
}

class _DetailPropositionScreenState
    extends ConsumerState<DetailPropositionScreen> {
  bool _enCours = false;

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _ouvrirLien(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok && mounted) {
      BlurredToast.show(
        context,
        'Lien impossible a ouvrir',
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _approuver(PropositionCours p) async {
    setState(() => _enCours = true);
    try {
      await ref.read(coursAdminServiceProvider).approuver(p);
      if (mounted) {
        BlurredToast.show(
          context,
          'Cours publie',
          icon: Icons.check_circle_outline,
        );
        context.go('/super-admin/propositions');
      }
    } catch (e) {
      if (mounted) {
        BlurredToast.show(context, 'Erreur : $e', icon: Icons.error_outline);
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _rejeter(PropositionCours p) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeter cette proposition ?'),
        content: const Text(
          'Elle ne sera plus proposee par la veille automatique.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    setState(() => _enCours = true);
    try {
      await ref.read(coursAdminServiceProvider).rejeter(p.id);
      if (mounted) {
        BlurredToast.show(
          context,
          'Proposition rejetee',
          icon: Icons.delete_outline,
        );
        context.go('/super-admin/propositions');
      }
    } catch (e) {
      if (mounted) {
        BlurredToast.show(context, 'Erreur : $e', icon: Icons.error_outline);
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final propositions = ref.watch(propositionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proposition'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/super-admin/propositions'),
        ),
      ),
      body: propositions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (liste) {
          final p = liste
              .where((x) => x.id == widget.propositionId)
              .firstOrNull;
          if (p == null) {
            return const Center(
              child: Text('Cette proposition n\'est plus en attente'),
            );
          }
          final c = p.cours;
          final image = c.lienImage;
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (image != null && image.isNotEmpty)
                SizedBox(
                  height: 180,
                  child: Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.titre,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(c.fournisseur)),
                        Chip(label: Text(c.niveau.label)),
                        Chip(label: Text(c.categorie)),
                        Chip(label: Text(c.langue)),
                        if (c.duree != null && c.duree!.isNotEmpty)
                          Chip(label: Text(c.duree!)),
                        if (c.certificatDisponible)
                          Chip(
                            label: Text(
                              c.certificatPayant
                                  ? 'Certificat payant'
                                  : 'Certificat gratuit',
                            ),
                          ),
                        if (c.dateFin != null)
                          Chip(label: Text('Fin le ${_date(c.dateFin!)}')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.aVerifier
                            ? AppColors.warning.withValues(alpha: 0.12)
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trouve sur ${p.sourceNom} - confiance de l\'IA : '
                            '${(p.confiance * 100).round()} %',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (p.remarques.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('A verifier : ${p.remarques}'),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Description courte',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(c.description),
                    const SizedBox(height: 14),
                    const Text(
                      'Description detaillee',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(c.descriptionDetaillee),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () => _ouvrirLien(c.lienCours),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Ouvrir le lien pour verifier'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _enCours ? null : () => _approuver(p),
                      icon: const Icon(Icons.check),
                      label: const Text('Approuver et publier'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _enCours
                          ? null
                          : () => context.go(
                              '/super-admin/propositions/${p.id}/modifier',
                            ),
                      icon: const Icon(Icons.edit),
                      label: const Text('Modifier puis publier'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _enCours ? null : () => _rejeter(p),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Rejeter'),
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
}
