import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/centre_provider.dart';
import '../../providers/user_provider.dart';

class CreerUtilisateurScreen extends ConsumerStatefulWidget {
  const CreerUtilisateurScreen({super.key});

  @override
  ConsumerState<CreerUtilisateurScreen> createState() =>
      _CreerUtilisateurScreenState();
}

class _CreerUtilisateurScreenState
    extends ConsumerState<CreerUtilisateurScreen> {
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  UserRole _roleSelectionne = UserRole.apprenant;
  String? _erreur;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _creer() async {
    setState(() => _erreur = null);

    if (_nomController.text.trim().isEmpty) {
      setState(() => _erreur = 'Le nom est obligatoire');
      return;
    }
    if (_prenomController.text.trim().isEmpty) {
      setState(() => _erreur = 'Le prenom est obligatoire');
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      setState(() => _erreur = 'Email invalide');
      return;
    }
    if (_passwordController.text.trim().length < 6) {
      setState(() => _erreur = 'Mot de passe minimum 6 caracteres');
      return;
    }

    var centreActif = ref.read(centreActifProvider);
    if (centreActif == null) {
      final centres = ref.read(centresDuAdminProvider).value ?? [];
      if (centres.isEmpty) {
        setState(() => _erreur = 'Aucun centre disponible');
        return;
      }
      centreActif = centres.first;
      ref.read(centreActifProvider.notifier).state = centreActif;
    }

    if (centreActif.id.isEmpty) {
      setState(
        () => _erreur =
            'Centre actif invalide, veuillez reselectionner le centre',
      );
      return;
    }

    final userProfile = ref.read(userProfileProvider).value;
    if (userProfile == null) {
      setState(() => _erreur = 'Profil utilisateur introuvable');
      return;
    }

    final prenom = _prenomController.text.trim();
    final nom = _nomController.text.trim();
    final email = _emailController.text.trim();
    final motDePasse = _passwordController.text.trim();
    final roleLabel = _roleSelectionne == UserRole.apprenant
        ? 'Apprenant'
        : 'Formateur';

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .creerCompteParAdmin(
            email: email,
            password: motDePasse,
            role: _roleSelectionne,
            nom: nom,
            prenom: prenom,
            centreId: centreActif.id,
          );

      if (mounted) {
        context.go(
          '/admin/users/succes',
          extra: {
            'prenom': prenom,
            'nom': nom,
            'email': email,
            'motDePasse': motDePasse,
            'role': roleLabel,
          },
        );
      }
    } catch (e) {
      String message = 'Erreur lors de la creation';
      if (e.toString().contains('email-already-in-use')) {
        message = 'Cet email est deja utilise';
      }
      setState(() => _erreur = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Creer un utilisateur'),
        backgroundColor: AppColors.primary, // Force le fond bleu
        foregroundColor: Colors.white, // Force le texte/icônes en blanc
        elevation: 0, // Optionnel : look plus moderne sans ombre
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // '/admin/users' est une route autonome héritée, sans bottom
          // navigation : revenir au shell (comme succes_creation_screen.dart)
          // plutôt que d'atterrir sur un écran orphelin sans les onglets.
          onPressed: () => context.go('/admin/dashboard'),
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
              const Text(
                'Role',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _roleSelectionne = UserRole.apprenant),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _roleSelectionne == UserRole.apprenant
                              ? AppColors.roleApprenant
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _roleSelectionne == UserRole.apprenant
                                ? AppColors.roleApprenant
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          'Apprenant',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _roleSelectionne == UserRole.apprenant
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _roleSelectionne = UserRole.formateur),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _roleSelectionne == UserRole.formateur
                              ? const Color.fromARGB(255, 228, 151, 18)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _roleSelectionne == UserRole.formateur
                                ? const Color.fromARGB(255, 228, 151, 18)
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          'Formateur',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _roleSelectionne == UserRole.formateur
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _prenomController,
                decoration: const InputDecoration(
                  labelText: 'Prenom',
                  prefixIcon: Icon(Icons.person_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  prefixIcon: Icon(Icons.person_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mot de passe temporaire',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'L utilisateur devra changer ce mot de passe a sa premiere connexion',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'Creer le compte',
                icon: Icons.person_add_rounded,
                isLoading: isLoading,
                onPressed: _creer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
