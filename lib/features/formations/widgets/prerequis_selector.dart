import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/formation_model.dart';

/// Sélecteur optionnel de "formation prérequise" (Phase 4), utilisé à la
/// création et à la modification d'une formation.
class PrerequisSelector extends StatelessWidget {
  final List<Formation> formationsDisponibles;
  final String? formationSelectionneeId;
  final ValueChanged<String?> onChanged;

  const PrerequisSelector({
    super.key,
    required this.formationsDisponibles,
    required this.formationSelectionneeId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Si la formation actuellement sélectionnée a disparu de la liste
    // (supprimée entre-temps), on affiche quand même le champ sans planter.
    final valeurValide =
        formationSelectionneeId != null &&
            formationsDisponibles.any((f) => f.id == formationSelectionneeId)
        ? formationSelectionneeId
        : null;

    return DropdownButtonFormField<String?>(
      initialValue: valeurValide,
      decoration: InputDecoration(
        labelText: 'Formation prerequise (optionnel)',
        prefixIcon: const Icon(Icons.link_rounded),
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
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Aucun prerequis'),
        ),
        ...formationsDisponibles.map(
          (f) => DropdownMenuItem<String?>(
            value: f.id,
            child: Text(f.titre, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
