import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/blurred_toast.dart';
import '../providers/cours_admin_provider.dart';

/// Où en est la veille automatique, et bouton pour la lancer.
class CarteEtatVeille extends ConsumerWidget {
  const CarteEtatVeille({super.key});

  static String _dateHeure(DateTime d) {
    String deux(int n) => n.toString().padLeft(2, '0');
    return '${deux(d.day)}/${deux(d.month)} a ${deux(d.hour)}h${deux(d.minute)}';
  }

  Future<void> _lancer(BuildContext context, WidgetRef ref) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lancer la veille ?'),
        content: const Text(
          'L\'IA va chercher de nouveaux cours sur les sites configures et '
          'deposer des propositions a valider. Rien n\'est publie sans votre '
          'accord.\n\n'
          'Le demarrage peut prendre jusqu\'a 10-15 minutes, puis quelques '
          'minutes de travail. L\'etat s\'affiche ici en direct.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lancer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await ref.read(coursAdminServiceProvider).lancerVeille();
      if (context.mounted) {
        BlurredToast.show(
          context,
          'Demande envoyee',
          icon: Icons.check_circle_outline,
        );
      }
    } catch (e) {
      if (context.mounted) {
        BlurredToast.show(
          context,
          e.toString().contains('deja en cours')
              ? 'Une veille est deja en cours'
              : 'Erreur : $e',
          icon: Icons.error_outline,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(etatVeilleProvider).value;
    final demande = ref.watch(derniereDemandeProvider).value;

    final demandeActive = demande != null && demande.active;
    final enAttente = demande?.statut == 'en_attente';
    final enCours = (demande?.statut == 'en_cours') || (etat?.enCours ?? false);
    final occupe = demandeActive || (etat?.enCours ?? false);

    IconData icone;
    Color couleur;
    String titre;
    String detail = '';

    if (enAttente && !(etat?.enCours ?? false)) {
      icone = Icons.hourglass_top;
      couleur = AppColors.info;
      titre = 'Demande envoyee, en attente de demarrage';
      final depuis = demande?.dateDemande;
      detail = depuis == null
          ? 'Cela peut prendre jusqu\'a 10-15 minutes.'
          : 'Envoyee le ${_dateHeure(depuis)}. Cela peut prendre jusqu\'a 10-15 minutes.';
      if (depuis != null &&
          DateTime.now().difference(depuis) > const Duration(minutes: 40)) {
        detail =
            'Le demarrage tarde (envoyee le ${_dateHeure(depuis)}). '
            'Verifiez l\'onglet Actions du depot GitHub.';
      }
    } else if (enCours) {
      icone = Icons.autorenew;
      couleur = AppColors.info;
      titre = 'Veille en cours...';
      final debut = etat?.debut;
      detail = debut == null
          ? 'Les propositions arrivent au fur et a mesure.'
          : 'Demarree le ${_dateHeure(debut)}. Les propositions arrivent au fur et a mesure.';
    } else if (etat != null && etat.enErreur) {
      icone = Icons.error_outline;
      couleur = AppColors.error;
      titre = 'La derniere veille a echoue';
      detail = etat.message;
    } else if (etat != null) {
      icone = Icons.check_circle_outline;
      couleur = AppColors.success;
      final fin = etat.fin ?? etat.debut;
      titre = fin == null
          ? 'Derniere veille terminee'
          : 'Derniere veille : ${_dateHeure(fin)}';
      detail = etat.message;
    } else {
      icone = Icons.auto_awesome;
      couleur = AppColors.textSecondary;
      titre = 'Aucune veille pour le moment';
      detail = 'Appuyez sur le bouton pour chercher de nouveaux cours.';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: couleur.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (enCours || (enAttente && !(etat?.enCours ?? false)))
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: couleur,
                    ),
                  ),
                )
              else
                Icon(icone, color: couleur),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: occupe ? null : () => _lancer(context, ref),
              icon: const Icon(Icons.play_arrow),
              label: Text(
                occupe ? 'Veille en cours...' : 'Lancer la veille maintenant',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
