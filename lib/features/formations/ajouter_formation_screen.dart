import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../models/formation_model.dart';
import '../../models/user_model.dart';
import '../../providers/formation_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/blurred_toast.dart';
import 'widgets/formation_image_picker.dart';
import 'widgets/prerequis_selector.dart';

class AjouterFormationScreen extends ConsumerStatefulWidget {
  const AjouterFormationScreen({super.key});

  @override
  ConsumerState<AjouterFormationScreen> createState() =>
      _AjouterFormationScreenState();
}

class _AjouterFormationScreenState
    extends ConsumerState<AjouterFormationScreen> {
  final _titreController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sessionsController = TextEditingController();
  final _fraisTotalController = TextEditingController();
  String _niveauSelectionne = 'Debutant';
  DateTime? _dateDebut;
  DateTime? _dateFin;
  String? _prerequisId;
  ({Uint8List bytes, String nomFichier})? _imageChoisie;
  String? _erreur;

  final List<String> _niveaux = ['Debutant', 'Intermediaire', 'Avance'];

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    _sessionsController.dispose();
    _fraisTotalController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _choisirDate(bool isDebut) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isDebut ? now : (_dateDebut ?? now),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      helpText: isDebut ? 'Date de debut' : 'Date de fin',
    );
    if (picked != null) {
      setState(() {
        if (isDebut) {
          _dateDebut = picked;
          if (_dateFin != null && _dateFin!.isBefore(picked)) {
            _dateFin = null;
          }
        } else {
          _dateFin = picked;
        }
      });
    }
  }

  Future<void> _soumettre() async {
    setState(() => _erreur = null);

    if (_titreController.text.trim().isEmpty) {
      setState(() => _erreur = 'Le titre est obligatoire');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _erreur = 'La description est obligatoire');
      return;
    }
    if (_sessionsController.text.trim().isEmpty) {
      setState(() => _erreur = 'Le nombre de sessions est obligatoire');
      return;
    }
    if (_dateDebut == null || _dateFin == null) {
      setState(() => _erreur = 'Les dates sont obligatoires');
      return;
    }

    final userProfile = ref.read(userProfileProvider).value;
    if (userProfile == null) {
      setState(
        () => _erreur = 'Profil utilisateur introuvable. Reconnectez-vous.',
      );
      return;
    }

    String centreId = '';

    if (userProfile.role == UserRole.admin) {
      // L'admin n'a pas de centreId sur son profil : on utilise le centre
      // actif (centreIdActifProvider), pas une requête indépendante — sinon
      // la formation peut être créée sous un centre différent de celui que
      // l'admin consulte, la rendant invisible dans le catalogue (cf. README
      // section 1, piège "Rôle-based centreId resolution").
      centreId = ref.read(centreIdActifProvider);
      if (centreId.isEmpty) {
        setState(
          () => _erreur = 'Aucun centre trouvé. Créez d\'abord un centre.',
        );
        return;
      }
    } else {
      // Le formateur utilise directement son centreId de profil
      centreId = userProfile.centreId;
    }

    if (centreId.isEmpty) {
      setState(() => _erreur = 'Erreur de configuration du centre.');
      return;
    }

    try {
      final formation = Formation(
        id: '',
        titre: _titreController.text.trim(),
        description: _descriptionController.text.trim(),
        formateurId: userProfile.id,
        formateurNom: '${userProfile.prenom} ${userProfile.nom}',
        nombreSessions: int.tryParse(_sessionsController.text.trim()) ?? 1,
        niveau: _niveauSelectionne,
        dateCreation: DateTime.now(),
        dateDebut: _dateDebut!,
        dateFin: _dateFin!,
        centreId: centreId,
        prerequisId: _prerequisId,
        fraisTotal: double.tryParse(
              _fraisTotalController.text.trim().replaceAll(',', '.'),
            ) ??
            0,
      );

      final creee =
          await ref.read(formationNotifierProvider.notifier).ajouter(formation);

      if (_imageChoisie != null) {
        // L'image a besoin de l'id de la formation (chemin de stockage) :
        // upload seulement possible une fois la formation créée. Un échec
        // ici n'annule pas la création, déjà réussie — juste un avertissement.
        try {
          final url = await ref.read(formationServiceProvider).uploaderImage(
                formationId: creee.id,
                nomFichier: _imageChoisie!.nomFichier,
                bytes: _imageChoisie!.bytes,
              );
          await ref
              .read(formationNotifierProvider.notifier)
              .modifier(creee.copyWith(imageUrl: url));
        } catch (e) {
          if (mounted) {
            BlurredToast.show(
              context,
              'Formation creee, mais l\'image n\'a pas pu etre enregistree : $e',
              icon: Icons.error_outline,
            );
          }
        }
      }

      if (mounted) {
        BlurredToast.show(
          context,
          'Formation ajoutée avec succès !',
          icon: Icons.check_circle_outline,
        );
        context.go('/formations');
      }
    } catch (e) {
      setState(() => _erreur = 'Erreur : ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final formationState = ref.watch(formationNotifierProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ajouter une formation'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/formations'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_erreur != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Text(
                    _erreur!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              FormationImagePicker(
                onImageSelectionnee: (image) => setState(() => _imageChoisie = image),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titreController,
                decoration: _buildInputDecoration(
                  'Titre de la formation',
                  Icons.book_rounded,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: _buildInputDecoration(
                  'Description',
                  Icons.description_outlined,
                ).copyWith(alignLabelWithHint: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _sessionsController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration(
                  'Nombre de sessions',
                  Icons.calendar_today_rounded,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _fraisTotalController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _buildInputDecoration(
                  'Frais total (FCFA, optionnel)',
                  Icons.payments_outlined,
                ),
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final formations = ref.watch(formationsProvider).value ?? [];
                  return PrerequisSelector(
                    formationsDisponibles: formations,
                    formationSelectionneeId: _prerequisId,
                    onChanged: (id) => setState(() => _prerequisId = id),
                  );
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _choisirDate(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(
                        _dateDebut == null
                            ? 'Date de debut'
                            : _formatDate(_dateDebut!),
                        style: TextStyle(
                          color: _dateDebut == null
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _choisirDate(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_available_rounded,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _dateFin == null
                            ? 'Date de fin'
                            : _formatDate(_dateFin!),
                        style: TextStyle(
                          color: _dateFin == null
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Niveau',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: _niveaux.map((niveau) {
                  final isSelected = _niveauSelectionne == niveau;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _niveauSelectionne = niveau),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          niveau,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'Ajouter la formation',
                icon: Icons.add_circle_rounded,
                isLoading: formationState.isLoading,
                onPressed: _soumettre,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
