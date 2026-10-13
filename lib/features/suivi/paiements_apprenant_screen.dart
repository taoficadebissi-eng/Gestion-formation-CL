import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/confirm_logout_dialog.dart';
import '../../models/inscription_model.dart';
import '../../models/paiement_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/centre_provider.dart';
import '../../providers/formation_provider.dart';
import '../../providers/inscription_provider.dart';
import '../../providers/paiement_provider.dart';
import '../../providers/user_provider.dart';

String _formatMontant(double montant) {
  final entier = montant.round();
  final chaine = entier.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < chaine.length; i++) {
    if (i > 0 && (chaine.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(chaine[i]);
  }
  return '${buffer.toString()} FCFA';
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

(Color, String) _styleStatut(StatutPaiement statut) {
  switch (statut) {
    case StatutPaiement.aJour:
      return (AppColors.success, 'A jour');
    case StatutPaiement.enRetard:
      return (AppColors.warning, 'En retard');
    case StatutPaiement.bloque:
      return (AppColors.error, 'Bloque');
  }
}

/// Onglet "Paiements" de l'apprenant (Phase 5) : solde par formation
/// suivie, historique des paiements, bouton "Payer maintenant" (UI
/// préparée — l'intégration Mobile Money réelle est une sous-étape séparée,
/// en attente de la clé API du fournisseur choisi).
class PaiementsApprenantScreen extends ConsumerWidget {
  const PaiementsApprenantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider).value;
    final centreAsync = ref.watch(centreActuelProvider);
    final nomCentre = centreAsync.when(
      data: (centre) => centre?.nom ?? 'Centre',
      loading: () => 'Chargement...',
      error: (_, _) => 'Centre',
    );

    final inscriptionsAsync = userProfile != null
        ? ref.watch(inscriptionsApprenantProvider(userProfile.id))
        : const AsyncValue.data(<InscriptionModel>[]);
    final formations = ref.watch(formationsProvider).value ?? [];

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
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        leadingWidth: 140,
        title: const Text('Paiements', style: TextStyle(color: Colors.white)),
        actions: [
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
      body: inscriptionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (inscriptions) {
          if (inscriptions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune formation suivie pour le moment',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: inscriptions.length,
            itemBuilder: (context, index) {
              final inscription = inscriptions[index];
              final formation = formations.where((f) => f.id == inscription.formationId).firstOrNull;
              final (couleur, label) = _styleStatut(inscription.statutPaiement);
              final fraisTotal = formation?.fraisTotal ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.softCard(radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formation?.titre ?? 'Formation',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                          child: Text(label, style: TextStyle(color: couleur, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    if (inscription.statutPaiement == StatutPaiement.bloque) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Acces aux notes de cours et au chat de groupe restreint tant que le solde n\'est pas regularise.',
                        style: TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(label: 'Frais total', valeur: _formatMontant(fraisTotal)),
                        ),
                        Expanded(
                          child: _MiniStat(label: 'Paye', valeur: _formatMontant(inscription.montantPaye), couleur: AppColors.success),
                        ),
                        Expanded(
                          child: _MiniStat(label: 'Restant', valeur: _formatMontant(inscription.montantRestant), couleur: AppColors.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraisTotal > 0 ? (inscription.montantPaye / fraisTotal).clamp(0, 1) : 0,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.history_rounded, size: 18),
                            label: const Text('Historique'),
                            onPressed: () => _afficherHistorique(context, inscription.id),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.payments_rounded, size: 18),
                            label: const Text('Payer'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                            onPressed: inscription.montantRestant <= 0
                                ? null
                                : () => _payerMaintenant(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _payerMaintenant(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Paiement en ligne'),
        content: const Text(
          'Le paiement en ligne par Mobile Money arrive bientot. '
          'En attendant, contactez votre centre de formation pour regler votre solde.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Compris')),
        ],
      ),
    );
  }

  void _afficherHistorique(BuildContext context, String inscriptionId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _HistoriquePaiementsSheet(inscriptionId: inscriptionId),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String valeur;
  final Color? couleur;
  const _MiniStat({required this.label, required this.valeur, this.couleur});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          valeur,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: couleur ?? AppColors.textPrimary),
        ),
      ],
    );
  }
}

class _HistoriquePaiementsSheet extends ConsumerWidget {
  final String inscriptionId;
  const _HistoriquePaiementsSheet({required this.inscriptionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paiementsAsync = ref.watch(paiementsInscriptionProvider(inscriptionId));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historique des paiements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            paiementsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Erreur : $e'),
              data: (paiements) {
                if (paiements.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Aucun paiement enregistre', style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: paiements.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final PaiementModel p = paiements[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
                        title: Text(_formatMontant(p.montant)),
                        subtitle: Text('${_formatDate(p.date)} — ${p.methode}${p.reference.isNotEmpty ? ' (${p.reference})' : ''}'),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
