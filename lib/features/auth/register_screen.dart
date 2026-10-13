import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/blurred_toast.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _obscurePassword = true;

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
      fillColor: AppColors.surface, // Fond blanc pour les champs
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
      floatingLabelStyle: const TextStyle(color: AppColors.primary),
    );
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  bool _emailValide(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final nom = _nomController.text.trim();
    final prenom = _prenomController.text.trim();
    final token = _tokenController.text.trim();

    if (nom.isEmpty) {
      BlurredToast.show(
        context,
        'Veuillez entrer votre nom',
        icon: Icons.error_outline,
      );
      return;
    }
    if (prenom.isEmpty) {
      BlurredToast.show(
        context,
        'Veuillez entrer votre prenom',
        icon: Icons.error_outline,
      );
      return;
    }
    if (!_emailValide(email)) {
      BlurredToast.show(
        context,
        'Veuillez entrer un e-mail valide',
        icon: Icons.error_outline,
      );
      return;
    }
    if (_passwordController.text.trim().length < 6) {
      BlurredToast.show(
        context,
        'Le mot de passe doit contenir au moins 6 caracteres',
        icon: Icons.error_outline,
      );
      return;
    }
    if (token.isEmpty) {
      BlurredToast.show(
        context,
        "Veuillez entrer votre code d'invitation",
        icon: Icons.error_outline,
      );
      return;
    }

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .inscriptionAdmin(
            email: email,
            password: _passwordController.text.trim(),
            nom: nom,
            prenom: prenom,
            invitationToken: token,
          );
      if (!mounted) return;

      BlurredToast.show(
        context,
        'Compte cree : verifiez votre e-mail pour continuer.',
        icon: Icons.mark_email_unread_outlined,
        duration: const Duration(seconds: 3),
      );
      // Le routeur redirige vers l'écran de vérification de l'e-mail.
      context.go('/verification-email');
    } catch (e) {
      if (!mounted) return;

      String message = 'Erreur lors de la creation du compte';
      if (e.toString().contains('invitation_invalide')) {
        message = "Code d'invitation invalide ou deja utilise";
      } else if (e.toString().contains('email-already-in-use')) {
        message = 'Cet e-mail est deja utilise';
      }
      BlurredToast.show(context, message, icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      // Fond de secours
      backgroundColor: AppColors.darkGradientStart,

      appBar: AppBar(
        title: const Text(
          'Activation du compte',
          style: TextStyle(color: Colors.white), // Titre en blanc
        ),
        backgroundColor: Colors.transparent, // AppBar bleue
        foregroundColor: null, // Icônes blanches
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/login'),
        ),
      ),

      body: Container(
        // Application du dégradé sombre
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.darkGradientStart, // #1a1a2e
              AppColors.darkGradientMid, // #16213e
              AppColors.darkGradientEnd, // #0f3460
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Icône ou titre décoratif optionnel
                const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 60,
                  color: Colors.white70,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Création de compte Admin',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),

                // CHAMP TOKEN
                TextField(
                  controller: _tokenController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _buildInputDecoration(
                    "Code d'invitation",
                    Icons.vpn_key_outlined,
                  ).copyWith(hintText: 'Ex: CENTRE-2026-XK9'),
                ),

                const SizedBox(height: 16),

                // CHAMP NOM
                TextField(
                  controller: _nomController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _buildInputDecoration(
                    'Nom',
                    Icons.person_outlined,
                  ),
                ),

                const SizedBox(height: 16),

                // CHAMP PRENOM
                TextField(
                  controller: _prenomController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _buildInputDecoration(
                    'Prenom',
                    Icons.person_outlined,
                  ),
                ),

                const SizedBox(height: 16),

                // CHAMP EMAIL
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _buildInputDecoration(
                    'Adresse e-mail',
                    Icons.email_outlined,
                  ),
                ),

                const SizedBox(height: 16),

                // CHAMP MOT DE PASSE
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _buildInputDecoration(
                    'Mot de passe',
                    Icons.lock_outlined,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                CustomButton(
                  label: 'Activer mon compte',
                  icon: Icons.person_add_rounded,
                  isLoading: isLoading,
                  onPressed: _register,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
