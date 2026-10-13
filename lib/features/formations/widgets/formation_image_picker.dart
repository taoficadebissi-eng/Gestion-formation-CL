import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Image de couverture d'une formation, saisie sous forme de lien https
/// (Firebase Storage n'étant pas disponible sur le plan gratuit). Un
/// aperçu s'affiche dès que le lien est renseigné.
class FormationImagePicker extends StatefulWidget {
  final String? imageUrlExistante;

  /// Appelé à chaque modification : lien saisi, ou null si le champ est vide.
  final ValueChanged<String?> onUrlChangee;

  const FormationImagePicker({
    super.key,
    this.imageUrlExistante,
    required this.onUrlChangee,
  });

  @override
  State<FormationImagePicker> createState() => _FormationImagePickerState();
}

class _FormationImagePickerState extends State<FormationImagePicker> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.imageUrlExistante ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _lienValide {
    final uri = Uri.tryParse(_controller.text.trim());
    return uri != null && uri.scheme == 'https' && uri.hasAuthority;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 160,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: _lienValide
              ? Image.network(
                  _controller.text.trim(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Center(
                    child: Text(
                      'Image introuvable',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : const Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 32,
                    color: AppColors.textSecondary,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Lien de l\'image de couverture (optionnel)',
            hintText: 'https://...',
          ),
          onChanged: (valeur) {
            setState(() {});
            final lien = valeur.trim();
            widget.onUrlChangee(lien.isEmpty ? null : lien);
          },
        ),
      ],
    );
  }
}
