import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/note_provider.dart';
import '../../../widgets/blurred_toast.dart';

IconData _iconePourFichier(String nomFichier) {
  final ext = nomFichier.split('.').last.toLowerCase();
  if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
  if (['png', 'jpg', 'jpeg', 'webp'].contains(ext)) return Icons.image_rounded;
  if (['doc', 'docx'].contains(ext)) return Icons.description_rounded;
  return Icons.insert_drive_file_rounded;
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

/// Section "Notes de cours" du détail formation : liste des fichiers
/// déposés par le formateur, avec upload (formateur/admin) et
/// ouverture/téléchargement (tout inscrit + formateur + admin).
class NotesSection extends ConsumerStatefulWidget {
  final String formationId;
  final String userId;
  final bool peutAjouter;

  /// true si l'apprenant courant a un statut de paiement "bloque" pour
  /// cette formation : les RLS masquent déjà les notes, ce booléen sert
  /// uniquement à afficher un message clair plutôt que "aucun fichier"
  /// (qui laisserait croire qu'il n'y a simplement rien à voir).
  final bool estBloque;

  const NotesSection({
    super.key,
    required this.formationId,
    required this.userId,
    required this.peutAjouter,
    this.estBloque = false,
  });

  @override
  ConsumerState<NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends ConsumerState<NotesSection> {
  bool _enCoursUpload = false;

  Future<void> _ajouterFichier() async {
    final nomController = TextEditingController();
    final lienController = TextEditingController();
    final valide = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter un document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomController,
              decoration: const InputDecoration(labelText: 'Nom du document'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lienController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Lien (https://...)',
                helperText: 'Google Drive, OneDrive, Dropbox...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    final nom = nomController.text.trim();
    final lien = lienController.text.trim();
    nomController.dispose();
    lienController.dispose();
    if (valide != true) return;
    if (nom.isEmpty || lien.isEmpty) {
      if (mounted) {
        BlurredToast.show(
          context,
          'Nom et lien obligatoires',
          icon: Icons.error_outline,
        );
      }
      return;
    }

    setState(() => _enCoursUpload = true);
    try {
      await ref
          .read(noteServiceProvider)
          .ajouterLien(
            formationId: widget.formationId,
            nomFichier: nom,
            url: lien,
            uploadePar: widget.userId,
          );
      if (mounted) {
        BlurredToast.show(
          context,
          'Document ajoute avec succes !',
          icon: Icons.check_circle_outline,
        );
      }
    } catch (e) {
      if (mounted) {
        BlurredToast.show(
          context,
          'Erreur lors de l\'ajout du document : $e',
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) setState(() => _enCoursUpload = false);
    }
  }

  Future<void> _ouvrirFichier(String url) async {
    try {
      // Pas de `canLaunchUrl` avant sur web : ça casse la chaine de geste
      // utilisateur et bloque la popup (piège déjà documenté au README).
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!ok && mounted) {
        BlurredToast.show(
          context,
          'Impossible d\'ouvrir ce fichier',
          icon: Icons.error_outline,
        );
      }
    } catch (e) {
      if (mounted) {
        BlurredToast.show(context, 'Erreur : $e', icon: Icons.error_outline);
      }
    }
  }

  Future<void> _supprimerFichier(String noteId) async {
    try {
      await ref.read(noteServiceProvider).supprimer(noteId);
      if (mounted) {
        BlurredToast.show(
          context,
          'Fichier supprime',
          icon: Icons.delete_outline,
        );
      }
    } catch (e) {
      if (mounted) {
        BlurredToast.show(
          context,
          'Erreur lors de la suppression : $e',
          icon: Icons.error_outline,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesFormationProvider(widget.formationId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Notes de cours',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (widget.peutAjouter)
              _enCoursUpload
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.add_circle_rounded,
                        color: AppColors.primary,
                      ),
                      tooltip: 'Ajouter un document',
                      onPressed: _ajouterFichier,
                    ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.estBloque)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.softCard(
              radius: 16,
              color: AppColors.error.withValues(alpha: 0.08),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, color: AppColors.error),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Acces restreint : le solde de cette formation n\'est pas a jour. '
                    'Contactez votre centre de formation pour regulariser votre situation.',
                    style: TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          notesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              'Erreur : $e',
              style: const TextStyle(color: AppColors.error),
            ),
            data: (notes) {
              if (notes.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.softCard(radius: 16),
                  child: const Text(
                    'Aucun document depose pour le moment',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              return Column(
                children: notes.map((note) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: AppTheme.softCard(radius: 14),
                    child: ListTile(
                      leading: Icon(
                        _iconePourFichier(note.nomFichier),
                        color: AppColors.primary,
                      ),
                      title: Text(
                        note.nomFichier,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Ajoute le ${_formatDate(note.dateAjout)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onTap: () => _ouvrirFichier(note.url),
                      trailing: widget.peutAjouter
                          ? IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                              tooltip: 'Supprimer',
                              onPressed: () => _supprimerFichier(note.id),
                            )
                          : const Icon(
                              Icons.download_rounded,
                              color: AppColors.textSecondary,
                            ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}
