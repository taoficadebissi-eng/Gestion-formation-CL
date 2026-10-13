import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../models/cours_gratuit_model.dart';
import '../providers/cours_admin_provider.dart';

/// Liste des cours publics (espace super-admin). Un appui ouvre le détail ;
/// le bouton flottant « + » ajoute un cours.
class ListeCoursAdminScreen extends ConsumerStatefulWidget {
  const ListeCoursAdminScreen({super.key});

  @override
  ConsumerState<ListeCoursAdminScreen> createState() =>
      _ListeCoursAdminScreenState();
}

class _ListeCoursAdminScreenState extends ConsumerState<ListeCoursAdminScreen> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final coursAsync = ref.watch(coursAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cours publics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/super-admin'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/super-admin/cours/nouveau'),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un cours'),
      ),
      body: coursAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (cours) {
          final filtres = cours.where((c) {
            final q = _recherche.toLowerCase();
            return q.isEmpty ||
                c.titre.toLowerCase().contains(q) ||
                c.fournisseur.toLowerCase().contains(q) ||
                c.categorie.toLowerCase().contains(q);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un cours...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  onChanged: (v) => setState(() => _recherche = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${cours.length} cours - ${cours.where((c) => c.actif).length} visibles',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
              Expanded(
                child: filtres.isEmpty
                    ? Center(
                        child: Text(
                          cours.isEmpty
                              ? 'Aucun cours pour le moment.\nAppuyez sur « Ajouter un cours ».'
                              : 'Aucun resultat',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: filtres.length,
                        itemBuilder: (context, index) =>
                            _CarteCours(cours: filtres[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CarteCours extends StatelessWidget {
  final CoursGratuit cours;
  const _CarteCours({required this.cours});

  @override
  Widget build(BuildContext context) {
    final image = cours.lienImage;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/super-admin/cours/${cours.id}'),
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
                          errorBuilder: (_, _, _) => const _ImageParDefaut(),
                        )
                      : const _ImageParDefaut(),
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
                      '${cours.fournisseur} - ${cours.niveau.label}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!cours.actif)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Chip(
                    label: Text('Masque'),
                    visualDensity: VisualDensity.compact,
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

class _ImageParDefaut extends StatelessWidget {
  const _ImageParDefaut();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: AppColors.brandGradient),
      ),
      child: const Icon(Icons.school_rounded, color: Colors.white70),
    );
  }
}
