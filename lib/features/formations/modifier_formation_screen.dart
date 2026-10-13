import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../models/formation_model.dart';
import '../../providers/formation_provider.dart';
import '../../widgets/blurred_toast.dart';
import 'widgets/formation_image_picker.dart';
import 'widgets/prerequis_selector.dart';

class ModifierFormationScreen extends ConsumerStatefulWidget {
  final Formation formation;
  const ModifierFormationScreen({super.key, required this.formation});

  @override
  ConsumerState<ModifierFormationScreen> createState() =>
      _ModifierFormationScreenState();
}

class _ModifierFormationScreenState
    extends ConsumerState<ModifierFormationScreen> {
  late TextEditingController _titreController;
  late TextEditingController _descriptionController;
  late TextEditingController _sessionsController;
  late TextEditingController _fraisTotalController;
  late String _niveauSelectionne;
  late DateTime _dateDebut;
  late DateTime _dateFin;
  late String? _prerequisId;
  String? _imageUrl;
  String? _erreur;

  final List<String> _niveaux = ['Debutant', 'Intermediaire', 'Avance'];

  // Style commun pour les TextField (Rectangle arrondi)
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
  void initState() {
    super.initState();
    _titreController = TextEditingController(text: widget.formation.titre);
    _descriptionController = TextEditingController(
      text: widget.formation.description,
    );
    _sessionsController = TextEditingController(
      text: widget.formation.nombreSessions.toString(),
    );
    _fraisTotalController = TextEditingController(
      text: widget.formation.fraisTotal == 0
          ? ''
          : widget.formation.fraisTotal.toString(),
    );
    _niveauSelectionne = widget.formation.niveau;
    _dateDebut = widget.formation.dateDebut;
    _dateFin = widget.formation.dateFin;
    _prerequisId = widget.formation.prerequisId;
    _imageUrl = widget.formation.imageUrl;
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
      initialDate: isDebut ? _dateDebut : _dateFin,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: isDebut ? 'Date de debut' : 'Date de fin',
    );
    if (picked != null) {
      setState(() {
        if (isDebut) {
          _dateDebut = picked;
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
    if (_dateFin.isBefore(_dateDebut)) {
      setState(
        () => _erreur = 'La date de fin doit etre apres la date de debut',
      );
      return;
    }
    try {
      final formation = Formation(
        id: widget.formation.id,
        titre: _titreController.text.trim(),
        description: _descriptionController.text.trim(),
        formateurId: widget.formation.formateurId,
        formateurNom: widget.formation.formateurNom,
        nombreSessions: int.tryParse(_sessionsController.text.trim()) ?? 1,
        niveau: _niveauSelectionne,
        dateCreation: widget.formation.dateCreation,
        dateDebut: _dateDebut,
        dateFin: _dateFin,
        centreId: widget.formation.centreId,
        prerequisId: _prerequisId,
        fraisTotal:
            double.tryParse(
              _fraisTotalController.text.trim().replaceAll(',', '.'),
            ) ??
            0,
        imageUrl: _imageUrl,
      );

      await ref.read(formationNotifierProvider.notifier).modifier(formation);
      if (mounted) {
        BlurredToast.show(
          context,
          'Formation modifiee avec succes !',
          icon: Icons.check_circle_outline,
          duration: const Duration(seconds: 2),
        );
        context.go('/formations');
      }
    } catch (e) {
      setState(() => _erreur = 'Erreur lors de la modification');
    }
  }

  @override
  Widget build(BuildContext context) {
    final formationState = ref.watch(formationNotifierProvider);
    final isLoading = formationState.isLoading;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Modifier la formation'),
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
                imageUrlExistante: widget.formation.imageUrl,
                onUrlChangee: (url) => _imageUrl = url,
              ),
              const SizedBox(height: 16),

              // CHAMP TITRE MODIFIÉ
              TextField(
                controller: _titreController,
                decoration: _buildInputDecoration(
                  'Titre de la formation',
                  Icons.book_rounded,
                ),
              ),

              const SizedBox(height: 16),

              // CHAMP DESCRIPTION MODIFIÉ
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: _buildInputDecoration(
                  'Description',
                  Icons.description_outlined,
                ).copyWith(alignLabelWithHint: true),
              ),

              const SizedBox(height: 16),

              // CHAMP SESSIONS MODIFIÉ
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _buildInputDecoration(
                  'Frais total (FCFA, optionnel)',
                  Icons.payments_outlined,
                ),
              ),

              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final formations = (ref.watch(formationsProvider).value ?? [])
                      .where((f) => f.id != widget.formation.id)
                      .toList();
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
                        _formatDate(_dateDebut),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
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
                        _formatDate(_dateFin),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
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
                label: 'Enregistrer les modifications',
                icon: Icons.save_rounded,
                isLoading: isLoading,
                onPressed: _soumettre,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
