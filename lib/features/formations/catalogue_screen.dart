import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/confirm_logout_dialog.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../models/formation_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/formation_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/blurred_toast.dart';

enum _TriDate { aucun, prochainesDabord, recentesDabord }

class CatalogueScreen extends ConsumerStatefulWidget {
  /// true quand cet écran est l'onglet "Formations" d'un shell à bottom
  /// navigation (Phase 1) : pas de flèche retour dans ce cas, l'onglet
  /// "Accueil" du même shell en tient déjà lieu. Reste à false pour l'usage
  /// historique en route poussée (ex: depuis "Voir le catalogue"), où la
  /// flèche retour vers le dashboard du rôle garde son sens.
  final bool embeddedInShell;

  const CatalogueScreen({super.key, this.embeddedInShell = false});

  @override
  ConsumerState<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends ConsumerState<CatalogueScreen> {
  String _recherche = '';
  String? _niveauFiltre;
  _TriDate _tri = _TriDate.aucun;
  bool _filtresOuverts = false;

  static const _niveaux = ['Debutant', 'Intermediaire', 'Avance'];

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

  List<Formation> _appliquerFiltres(List<Formation> formations) {
    var resultat = formations.where((f) {
      final texte = _recherche.trim().toLowerCase();
      final matchTexte =
          texte.isEmpty ||
          f.titre.toLowerCase().contains(texte) ||
          f.formateurNom.toLowerCase().contains(texte);
      final matchNiveau = _niveauFiltre == null || f.niveau == _niveauFiltre;
      return matchTexte && matchNiveau;
    }).toList();

    switch (_tri) {
      case _TriDate.prochainesDabord:
        resultat.sort((a, b) => a.dateDebut.compareTo(b.dateDebut));
        break;
      case _TriDate.recentesDabord:
        resultat.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
        break;
      case _TriDate.aucun:
        break;
    }
    return resultat;
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider).value;
    final formationsAsync = ref.watch(formationsProvider);
    final peutAjouter =
        userProfile?.role == UserRole.admin ||
        userProfile?.role == UserRole.formateur;
    final estAdmin = userProfile?.role == UserRole.admin;
    final estFormateur = userProfile?.role == UserRole.formateur;
    final estApprenant = userProfile?.role == UserRole.apprenant;
    final nomComplet = userProfile != null
        ? '${userProfile.prenom} ${userProfile.nom}'
        : '';
    final aDesFiltresActifs = _niveauFiltre != null || _tri != _TriDate.aucun;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue des formations'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: widget.embeddedInShell
            ? null
            : estAdmin
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/admin/dashboard'),
              )
            : estApprenant
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/espace-apprenant'),
              )
            : estFormateur
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/dashboard-formateur'),
              )
            : null,
        automaticallyImplyLeading: false,
        actions: [
          if (nomComplet.isNotEmpty)
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
            icon: const Icon(Icons.logout),
            tooltip: 'Se deconnecter',
            onPressed: () => _deconnecter(context, ref),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: formationsAsync.when(
          loading: () => const SkeletonListLoader(itemCount: 5),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (formations) {
            final filtrees = _appliquerFiltres(formations);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Formations disponibles',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _BarreRecherche(
                  valeur: _recherche,
                  onChanged: (v) => setState(() => _recherche = v),
                  filtresOuverts: _filtresOuverts,
                  filtresActifs: aDesFiltresActifs,
                  onToggleFiltres: () =>
                      setState(() => _filtresOuverts = !_filtresOuverts),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: _filtresOuverts
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _PanneauFiltres(
                      niveaux: _niveaux,
                      niveauSelectionne: _niveauFiltre,
                      onNiveauSelected: (n) =>
                          setState(() => _niveauFiltre = n),
                      tri: _tri,
                      onTriSelected: (t) => setState(() => _tri = t),
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                Text(
                  '${filtrees.length} formation(s)'
                  '${formations.length != filtrees.length ? ' sur ${formations.length}' : ''}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: formations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.book_outlined,
                                size: 64,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Aucune formation disponible',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                              if (peutAjouter) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Appuyez sur + pour en ajouter une',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : filtrees.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 56,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Aucun resultat pour ces criteres',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() {
                                  _recherche = '';
                                  _niveauFiltre = null;
                                  _tri = _TriDate.aucun;
                                }),
                                child: const Text('Reinitialiser les filtres'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtrees.length,
                          itemBuilder: (context, index) {
                            final formation = filtrees[index];
                            final peutModifier =
                                userProfile?.role == UserRole.admin ||
                                userProfile?.id == formation.formateurId;
                            return GestureDetector(
                              onTap: () =>
                                  context.go('/formations/${formation.id}'),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: AppTheme.softCard(radius: 18),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          12,
                                        ),
                                      ),
                                      child: (formation.imageUrl != null &&
                                              formation.imageUrl!.isNotEmpty)
                                          ? Image.network(
                                              formation.imageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => const Icon(
                                                Icons.book_rounded,
                                                color: AppColors.primary,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.book_rounded,
                                              color: AppColors.primary,
                                            ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            formation.titre,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            formation.formateurNom.isEmpty
                                                ? 'Formateur non defini'
                                                : formation.formateurNom,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.calendar_today_rounded,
                                                size: 12,
                                                color:
                                                    AppColors.textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${formation.nombreSessions} sessions',
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        8,
                                                      ),
                                                ),
                                                child: Text(
                                                  formation.niveau,
                                                  style: const TextStyle(
                                                    color: AppColors.primary,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (peutModifier)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.more_vert,
                                          color: AppColors.textSecondary,
                                        ),
                                        onPressed: () => _afficherOptions(
                                          context,
                                          ref,
                                          formation.id,
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
      floatingActionButton: peutAjouter
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () => context.go('/formations/ajouter'),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  void _afficherOptions(
    BuildContext context,
    WidgetRef ref,
    String formationId,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AppColors.error),
              title: const Text(
                'Supprimer',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await ref
                      .read(formationNotifierProvider.notifier)
                      .supprimer(formationId);
                  if (context.mounted) {
                    BlurredToast.show(
                      context,
                      'Formation supprimee',
                      icon: Icons.delete_outline,
                      duration: const Duration(seconds: 2),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    BlurredToast.show(
                      context,
                      'Erreur lors de la suppression : $e',
                      icon: Icons.error_outline,
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BarreRecherche extends StatelessWidget {
  final String valeur;
  final ValueChanged<String> onChanged;
  final bool filtresOuverts;
  final bool filtresActifs;
  final VoidCallback onToggleFiltres;

  const _BarreRecherche({
    required this.valeur,
    required this.onChanged,
    required this.filtresOuverts,
    required this.filtresActifs,
    required this.onToggleFiltres,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.softCard(radius: 16),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search_rounded, color: AppColors.textSecondary),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: 'Rechercher par titre ou formateur...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Filtres avances',
            onPressed: onToggleFiltres,
            icon: Icon(
              filtresOuverts ? Icons.expand_less_rounded : Icons.tune_rounded,
              color: filtresActifs
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanneauFiltres extends StatelessWidget {
  final List<String> niveaux;
  final String? niveauSelectionne;
  final ValueChanged<String?> onNiveauSelected;
  final _TriDate tri;
  final ValueChanged<_TriDate> onTriSelected;

  const _PanneauFiltres({
    required this.niveaux,
    required this.niveauSelectionne,
    required this.onNiveauSelected,
    required this.tri,
    required this.onTriSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Niveau',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tous'),
                selected: niveauSelectionne == null,
                onSelected: (_) => onNiveauSelected(null),
              ),
              ...niveaux.map(
                (n) => ChoiceChip(
                  label: Text(n),
                  selected: niveauSelectionne == n,
                  onSelected: (_) => onNiveauSelected(n),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Trier par date',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Par defaut'),
                selected: tri == _TriDate.aucun,
                onSelected: (_) => onTriSelected(_TriDate.aucun),
              ),
              ChoiceChip(
                label: const Text('Prochaines d\'abord'),
                selected: tri == _TriDate.prochainesDabord,
                onSelected: (_) => onTriSelected(_TriDate.prochainesDabord),
              ),
              ChoiceChip(
                label: const Text('Recemment ajoutees'),
                selected: tri == _TriDate.recentesDabord,
                onSelected: (_) => onTriSelected(_TriDate.recentesDabord),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
