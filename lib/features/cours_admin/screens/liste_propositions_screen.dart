import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../models/proposition_model.dart';
import '../providers/cours_admin_provider.dart';
import '../widgets/carte_etat_veille.dart';

/// Cours trouvés par la veille automatique, à valider un par un.
class ListePropositionsScreen extends ConsumerWidget {
  const ListePropositionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propositions = ref.watch(propositionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Propositions de cours'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/super-admin'),
        ),
      ),
      body: propositions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (liste) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const CarteEtatVeille(),
              if (liste.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  child: Text(
                    'Aucune proposition en attente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Text(
                    '${liste.length} proposition${liste.length > 1 ? "s" : ""} a valider',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ...liste.map((p) => _CarteProposition(proposition: p)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CarteProposition extends StatelessWidget {
  final PropositionCours proposition;
  const _CarteProposition({required this.proposition});

  @override
  Widget build(BuildContext context) {
    final cours = proposition.cours;
    final image = cours.lienImage;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: proposition.aVerifier ? AppColors.warning : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/super-admin/propositions/${proposition.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 84,
                  height: 64,
                  child: (image != null && image.isNotEmpty)
                      ? Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const _Degrade(),
                        )
                      : const _Degrade(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cours.titre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${proposition.sourceNom} - ${cours.categorie} - '
                      'confiance ${(proposition.confiance * 100).round()} %',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (proposition.aVerifier)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: AppColors.warning,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'A verifier',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Degrade extends StatelessWidget {
  const _Degrade();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: AppColors.brandGradient),
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white70),
    );
  }
}
