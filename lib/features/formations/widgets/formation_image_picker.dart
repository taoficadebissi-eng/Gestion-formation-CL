import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/blurred_toast.dart';

/// Sélecteur d'image de couverture pour une formation (Phase 7). L'upload
/// réel se fait au moment de la soumission du formulaire (on a besoin de
/// l'id de la formation, généré à la création) : ce widget se contente de
/// choisir le fichier et d'exposer ses octets via [onImageSelectionnee].
class FormationImagePicker extends StatefulWidget {
  final String? imageUrlExistante;
  final ValueChanged<({Uint8List bytes, String nomFichier})?> onImageSelectionnee;

  const FormationImagePicker({
    super.key,
    this.imageUrlExistante,
    required this.onImageSelectionnee,
  });

  @override
  State<FormationImagePicker> createState() => _FormationImagePickerState();
}

class _FormationImagePickerState extends State<FormationImagePicker> {
  Uint8List? _previewBytes;

  Future<void> _choisir() async {
    try {
      // pickFile() (singulier) n'est pas encore implémenté sur le web par
      // file_picker 12.x — utiliser pickFiles() avec allowMultiple: false
      // (déprécié mais fonctionnel) en attendant.
      // ignore: deprecated_member_use
      final fichiers = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        // ignore: deprecated_member_use
        allowMultiple: false,
      );
      if (fichiers.isEmpty) return;
      final fichier = fichiers.first;
      final bytes = await fichier.readAsBytes();
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        if (mounted) {
          BlurredToast.show(context, 'Image trop lourde (max 5 Mo)', icon: Icons.error_outline);
        }
        return;
      }
      setState(() => _previewBytes = bytes);
      widget.onImageSelectionnee((bytes: bytes, nomFichier: fichier.name));
    } catch (e) {
      if (mounted) {
        BlurredToast.show(context, 'Erreur : $e', icon: Icons.error_outline);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _choisir,
      child: Container(
        height: 160,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: _previewBytes != null
            ? Image.memory(_previewBytes!, fit: BoxFit.cover)
            : (widget.imageUrlExistante != null && widget.imageUrlExistante!.isNotEmpty)
                ? Image.network(widget.imageUrlExistante!, fit: BoxFit.cover)
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 32, color: AppColors.textSecondary),
                        SizedBox(height: 8),
                        Text(
                          'Ajouter une image de couverture (optionnel)',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
