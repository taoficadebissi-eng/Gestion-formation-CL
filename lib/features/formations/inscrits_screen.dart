import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/inscription_model.dart';
import '../../providers/inscription_provider.dart';
import 'widgets/detail_paiement_sheet.dart';

class InscritsScreen extends ConsumerWidget {
  final String formationId;
  final String formationTitre;

  const InscritsScreen({
    super.key,
    required this.formationId,
    required this.formationTitre,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inscriptionsAsync = ref.watch(
      inscriptionsFormationProvider(formationId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Apprenants inscrits'),
        backgroundColor: AppColors.primary, // Force le fond bleu
        foregroundColor: Colors.white, // Force le texte/icônes en blanc
        elevation: 0, // Optionnel : look plus moderne sans ombre
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/formations/$formationId'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: inscriptionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (inscriptions) {
            if (inscriptions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 64,
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    const Text(
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${inscriptions.length} apprenant(s) inscrit(s)',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: inscriptions.length,
                    itemBuilder: (context, index) {
                      final inscription = inscriptions[index];
                      return GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          builder: (_) =>
                              DetailPaiementSheet(inscription: inscription),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.roleApprenant.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.roleApprenant,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      inscription.apprenantNom,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Inscrit le ${inscription.dateInscription.day.toString().padLeft(2, '0')}/${inscription.dateInscription.month.toString().padLeft(2, '0')}/${inscription.dateInscription.year}',
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
                                  color: _couleurStatutPaiement(
                                    inscription.statutPaiement,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _libelleStatutPaiement(
                                    inscription.statutPaiement,
                                  ),
                                  style: TextStyle(
                                    color: _couleurStatutPaiement(
                                      inscription.statutPaiement,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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
    );
  }
}

Color _couleurStatutPaiement(StatutPaiement statut) {
  switch (statut) {
    case StatutPaiement.aJour:
      return AppColors.success;
    case StatutPaiement.enRetard:
      return AppColors.warning;
    case StatutPaiement.bloque:
      return AppColors.error;
  }
}

String _libelleStatutPaiement(StatutPaiement statut) {
  switch (statut) {
    case StatutPaiement.aJour:
      return 'A jour';
    case StatutPaiement.enRetard:
      return 'En retard';
    case StatutPaiement.bloque:
      return 'Bloque';
  }
}
