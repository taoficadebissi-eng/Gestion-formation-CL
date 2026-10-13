import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/blurred_toast.dart';
import '../models/cours_gratuit_model.dart';
import '../providers/cours_admin_provider.dart';

/// Ajout (coursId == null) ou modification d'un cours.
class FormulaireCoursScreen extends ConsumerStatefulWidget {
  final String? coursId;
  const FormulaireCoursScreen({super.key, this.coursId});

  @override
  ConsumerState<FormulaireCoursScreen> createState() =>
      _FormulaireCoursScreenState();
}

class _FormulaireCoursScreenState extends ConsumerState<FormulaireCoursScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titre = TextEditingController();
  final _description = TextEditingController();
  final _descriptionDetaillee = TextEditingController();
  final _fournisseur = TextEditingController();
  final _duree = TextEditingController();
  final _langue = TextEditingController(text: 'Francais');
  final _categorie = TextEditingController();
  final _lienCours = TextEditingController();
  final _lienImage = TextEditingController();
  final _ordre = TextEditingController();

  NiveauCours _niveau = NiveauCours.debutant;
  bool _certificatDisponible = false;
  bool _certificatPayant = false;
  bool _actif = true;
  bool _enregistrement = false;
  bool _initialise = false;
  CoursGratuit? _existant;

  bool get _modification => widget.coursId != null;

  @override
  void dispose() {
    for (final c in [
      _titre,
      _description,
      _descriptionDetaillee,
      _fournisseur,
      _duree,
      _langue,
      _categorie,
      _lienCours,
      _lienImage,
      _ordre,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _remplir(CoursGratuit c) {
    _existant = c;
    _titre.text = c.titre;
    _description.text = c.description;
    _descriptionDetaillee.text = c.descriptionDetaillee;
    _fournisseur.text = c.fournisseur;
    _duree.text = c.duree ?? '';
    _langue.text = c.langue;
    _categorie.text = c.categorie;
    _lienCours.text = c.lienCours;
    _lienImage.text = c.lienImage ?? '';
    _ordre.text = c.ordreAffichage?.toString() ?? '';
    _niveau = c.niveau;
    _certificatDisponible = c.certificatDisponible;
    _certificatPayant = c.certificatPayant;
    _actif = c.actif;
  }

  String? _requis(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requis' : null;

  String? _lienHttps(String? v, {bool optionnel = false}) {
    final texte = v?.trim() ?? '';
    if (texte.isEmpty) return optionnel ? null : 'Requis';
    final uri = Uri.tryParse(texte);
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
      return 'Le lien doit commencer par https://';
    }
    return null;
  }

  InputDecoration _decoration(String label, {bool optionnel = false}) {
    return InputDecoration(
      labelText: optionnel ? '$label (optionnel)' : label,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }

  Widget _section(String titre) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 12),
    child: Text(
      titre,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        color: AppColors.textSecondary,
      ),
    ),
  );

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enregistrement = true);
    try {
      final base = _existant ?? CoursGratuit.empty();
      final cours = base.copyWith(
        titre: _titre.text.trim(),
        description: _description.text.trim(),
        descriptionDetaillee: _descriptionDetaillee.text.trim(),
        fournisseur: _fournisseur.text.trim(),
        niveau: _niveau,
        duree: _duree.text.trim().isEmpty ? null : _duree.text.trim(),
        langue: _langue.text.trim(),
        certificatDisponible: _certificatDisponible,
        certificatPayant: _certificatDisponible && _certificatPayant,
        categorie: _categorie.text.trim(),
        lienCours: _lienCours.text.trim(),
        lienImage: _lienImage.text.trim().isEmpty
            ? null
            : _lienImage.text.trim(),
        actif: _actif,
        ordreAffichage: int.tryParse(_ordre.text.trim()),
      );
      final service = ref.read(coursAdminServiceProvider);
      if (_modification) {
        await service.modifier(cours);
      } else {
        await service.ajouter(cours);
      }
      if (mounted) {
        BlurredToast.show(
          context,
          _modification ? 'Cours modifie' : 'Cours ajoute',
          icon: Icons.check_circle_outline,
        );
        context.go('/super-admin/cours');
      }
    } catch (e) {
      if (mounted) {
        BlurredToast.show(context, 'Erreur : $e', icon: Icons.error_outline);
      }
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_modification && !_initialise) {
      final coursAsync = ref.watch(coursAdminProvider);
      return coursAsync.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('Erreur : $e'))),
        data: (liste) {
          final cours = liste.where((c) => c.id == widget.coursId).firstOrNull;
          if (cours == null) {
            return const Scaffold(
              body: Center(child: Text('Ce cours n\'existe plus')),
            );
          }
          _remplir(cours);
          _initialise = true;
          return _formulaire();
        },
      );
    }
    return _formulaire();
  }

  Widget _formulaire() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_modification ? 'Modifier le cours' : 'Nouveau cours'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(
            _modification
                ? '/super-admin/cours/${widget.coursId}'
                : '/super-admin/cours',
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section('INFORMATIONS PRINCIPALES'),
                  TextFormField(
                    controller: _titre,
                    decoration: _decoration('Titre *'),
                    validator: _requis,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _fournisseur,
                    decoration: _decoration('Fournisseur * (ex: Coursera)'),
                    validator: _requis,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<NiveauCours>(
                    initialValue: _niveau,
                    decoration: _decoration('Niveau *'),
                    items: NiveauCours.values
                        .map(
                          (n) =>
                              DropdownMenuItem(value: n, child: Text(n.label)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _niveau = v!),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _categorie,
                    decoration: _decoration('Categorie * (ex: Informatique)'),
                    validator: _requis,
                  ),
                  _section('DESCRIPTIONS'),
                  TextFormField(
                    controller: _description,
                    decoration: _decoration('Description courte *'),
                    maxLines: 3,
                    maxLength: 220,
                    validator: _requis,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionDetaillee,
                    decoration: _decoration('Description detaillee *'),
                    maxLines: 6,
                    validator: _requis,
                  ),
                  _section('LIENS'),
                  TextFormField(
                    controller: _lienCours,
                    decoration: _decoration(
                      'Lien vers le cours * (https://...)',
                    ),
                    keyboardType: TextInputType.url,
                    validator: (v) => _lienHttps(v),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _lienImage,
                    decoration: _decoration(
                      'Lien de l\'image (https://...)',
                      optionnel: true,
                    ),
                    keyboardType: TextInputType.url,
                    validator: (v) => _lienHttps(v, optionnel: true),
                  ),
                  _section('DETAILS'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _duree,
                          decoration: _decoration('Duree', optionnel: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _langue,
                          decoration: _decoration('Langue *'),
                          validator: _requis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _ordre,
                    decoration: _decoration(
                      'Ordre d\'affichage (1 = en premier)',
                      optionnel: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  _section('OPTIONS'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          title: const Text('Certificat disponible'),
                          value: _certificatDisponible,
                          onChanged: (v) => setState(
                            () => _certificatDisponible = v ?? false,
                          ),
                        ),
                        if (_certificatDisponible)
                          CheckboxListTile(
                            title: const Text('Certificat payant'),
                            value: _certificatPayant,
                            onChanged: (v) =>
                                setState(() => _certificatPayant = v ?? false),
                          ),
                        CheckboxListTile(
                          title: const Text('Cours visible sur la vitrine'),
                          value: _actif,
                          onChanged: (v) => setState(() => _actif = v ?? true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _enregistrement ? null : _enregistrer,
                    child: _enregistrement
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _modification
                                ? 'ENREGISTRER LES MODIFICATIONS'
                                : 'PUBLIER LE COURS',
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
