import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/user_service.dart';
import '../../widgets/blurred_toast.dart';

class ChangerMotDePasseScreen extends ConsumerStatefulWidget {
  const ChangerMotDePasseScreen({super.key});

  @override
  ConsumerState<ChangerMotDePasseScreen> createState() =>
      _ChangerMotDePasseScreenState();
}

class _ChangerMotDePasseScreenState
    extends ConsumerState<ChangerMotDePasseScreen> {
  final _nouveauController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureNouveau = true;
  bool _obscureConfirm = true;
  String? _erreur;

  // Style commun pour les TextField (Rectangle arrondi)
  InputDecoration _buildInputDecoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
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
    _nouveauController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changerMotDePasse() async {
    setState(() => _erreur = null);

    final nouveau = _nouveauController.text.trim();
    final confirm = _confirmController.text.trim();

    if (nouveau.length < 6) {
      setState(
        () => _erreur = 'Le mot de passe doit contenir au moins 6 caracteres',
      );
      return;
    }
    if (nouveau != confirm) {
      setState(() => _erreur = 'Les mots de passe ne correspondent pas');
      return;
    }

    final userProfile = ref.read(userProfileProvider).value;
    if (userProfile == null) {
      setState(() => _erreur = 'Profil introuvable, veuillez vous reconnecter');
      return;
    }

    try {
      await ref.read(authNotifierProvider.notifier).changerMotDePasse(nouveau);
      await UserService().marquerMotDePasseChange(userProfile.id);

      if (!mounted) return;

      BlurredToast.show(
        context,
        'Mot de passe mis a jour avec succes !',
        icon: Icons.check_circle_outline,
        duration: const Duration(seconds: 2),
      );
      _redirigerSelonRole(userProfile.role);
    } catch (e) {
      if (!mounted) return;

      String message = 'Erreur lors du changement de mot de passe';
      if (e.toString().contains('requires-recent-login')) {
        message = 'Session expiree. Veuillez vous reconnecter';
      } else if (e.toString().contains('weak-password')) {
        message = 'Mot de passe trop faible';
      }
      setState(() => _erreur = message);
    }
  }

  void _redirigerSelonRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        context.go('/admin/dashboard');
      case UserRole.formateur:
        context.go('/dashboard-formateur');
      case UserRole.apprenant:
        context.go('/espace-apprenant');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final userProfileAsync = ref.watch(userProfileProvider);
    final userProfile = userProfileAsync.value;

    // VÉRIFICATION : Si c'est un admin, rediriger immédiatement
    if (userProfile != null && userProfile.role == UserRole.admin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/admin/dashboard');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Icon(
                Icons.lock_reset_rounded,
                size: 56,
                color: AppColors.primary,
              ),
              const SizedBox(height: 20),
              const Text(
                'Creer votre mot de passe',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Votre mot de passe temporaire doit etre remplace. '
                'Choisissez un mot de passe personnel et securise.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 40),
              if (_erreur != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
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

              // CHAMP NOUVEAU MDP MODIFIÉ
              TextField(
                controller: _nouveauController,
                obscureText: _obscureNouveau,
                decoration: _buildInputDecoration(
                  'Nouveau mot de passe',
                  Icons.lock_outlined,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNouveau ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureNouveau = !_obscureNouveau),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // CHAMP CONFIRMATION MDP MODIFIÉ
              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: _buildInputDecoration(
                  'Confirmer le mot de passe',
                  Icons.lock_outlined,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              const Text(
                'Minimum 6 caracteres',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 40),
              CustomButton(
                label: 'Valider le mot de passe',
                icon: Icons.check_rounded,
                isLoading: isLoading,
                onPressed: _changerMotDePasse,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
