import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/inscription_model.dart';
import '../../../providers/formation_provider.dart';
import '../../../providers/inscription_provider.dart';
import '../../../providers/paiement_provider.dart';
import '../../../widgets/blurred_toast.dart';

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

/// Détail paiement d'un apprenant inscrit, ouvert depuis inscrits_screen.dart
/// (admin) : solde, historique, enregistrement d'un paiement manuel,
/// bascule bloqué/débloqué.
class DetailPaiementSheet extends ConsumerStatefulWidget {
  final InscriptionModel inscription;
  const DetailPaiementSheet({super.key, required this.inscription});

  @override
  ConsumerState<DetailPaiementSheet> createState() =>
      _DetailPaiementSheetState();
}

class _DetailPaiementSheetState extends ConsumerState<DetailPaiementSheet> {
  final _montantController = TextEditingController();
  final _referenceController = TextEditingController();
  bool _enCours = false;

  @override
  void dispose() {
    _montantController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final montant = double.tryParse(
      _montantController.text.trim().replaceAll(',', '.'),
    );
    if (montant == null || montant <= 0) {
      BlurredToast.show(context, 'Montant invalide', icon: Icons.error_outline);
      return;
    }
    setState(() => _enCours = true);
    try {
      await ref
          .read(inscriptionNotifierProvider.notifier)
          .enregistrerPaiement(
            inscriptionId: widget.inscription.id,
            montant: montant,
            methode: 'manuel',
            reference: _referenceController.text.trim(),
          );
      if (mounted) {
        BlurredToast.show(
          context,
          'Paiement enregistre !',
          icon: Icons.check_circle_outline,
        );
        _montantController.clear();
        _referenceController.clear();
      }
    } catch (e) {
      if (mounted) {
        BlurredToast.show(
          context,
          'Erreur lors de l\'enregistrement du paiement : $e',
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _basculerBlocage(bool bloquer) async {
    try {
      await ref
          .read(inscriptionNotifierProvider.notifier)
          .togglerBlocage(widget.inscription.id, bloquer);
      if (mounted) {
        BlurredToast.show(
          context,
          bloquer ? 'Acces bloque' : 'Acces debloque',
          icon: bloquer ? Icons.lock_outline : Icons.lock_open_outlined,
        );
      }
    } catch (e) {
      if (mounted) {
        BlurredToast.show(context, 'Erreur : $e', icon: Icons.error_outline);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formations = ref.watch(formationsProvider).value ?? [];
    final formation = formations
        .where((f) => f.id == widget.inscription.formationId)
        .firstOrNull;
    final fraisTotal = formation?.fraisTotal ?? 0;
    final paiementsAsync = ref.watch(
      paiementsInscriptionProvider(widget.inscription.id),
    );
    final estBloque =
        widget.inscription.statutPaiement == StatutPaiement.bloque;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.inscription.apprenantNom,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                formation?.titre ?? '',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Stat(
                    label: 'Frais total',
                    valeur: _formatMontant(fraisTotal),
                  ),
                  _Stat(
                    label: 'Paye',
                    valeur: _formatMontant(widget.inscription.montantPaye),
                    couleur: AppColors.success,
                  ),
                  _Stat(
                    label: 'Restant',
                    valeur: _formatMontant(widget.inscription.montantRestant),
                    couleur: AppColors.error,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Enregistrer un paiement manuel',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _montantController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Montant (FCFA)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Reference (optionnel)',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _enCours
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Enregistrer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _enCours ? null : _enregistrer,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(
                    estBloque ? Icons.lock_open_outlined : Icons.lock_outline,
                    color: AppColors.error,
                  ),
                  label: Text(
                    estBloque
                        ? 'Debloquer l\'acces'
                        : 'Bloquer l\'acces (notes + chat)',
                    style: const TextStyle(color: AppColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: () => _basculerBlocage(!estBloque),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Historique des paiements',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              paiementsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Erreur : $e'),
                data: (paiements) {
                  if (paiements.isEmpty) {
                    return const Text(
                      'Aucun paiement enregistre',
                      style: TextStyle(color: AppColors.textSecondary),
                    );
                  }
                  return Column(
                    children: paiements
                        .map(
                          (p) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.check_circle_outline,
                              color: AppColors.success,
                            ),
                            title: Text(_formatMontant(p.montant)),
                            subtitle: Text(
                              '${_formatDate(p.date)} — ${p.methode}${p.reference.isNotEmpty ? ' (${p.reference})' : ''}',
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String valeur;
  final Color? couleur;
  const _Stat({required this.label, required this.valeur, this.couleur});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          valeur,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: couleur ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
