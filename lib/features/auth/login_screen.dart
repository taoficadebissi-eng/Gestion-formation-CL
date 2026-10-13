import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/blurred_toast.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _erreur;
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
      // Couleur du label quand il est flottant
      floatingLabelStyle: const TextStyle(color: AppColors.primary),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _emailValide(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _login() async {
    setState(() => _erreur = null);
    final email = _emailController.text.trim();
    if (!_emailValide(email)) {
      BlurredToast.show(
        context,
        'Veuillez entrer un e-mail valide',
        icon: Icons.error_outline,
      );
      return;
    }
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .connexion(email, _passwordController.text.trim());
      if (mounted) {
        BlurredToast.show(
          context,
          'Connexion reussie !',
          icon: Icons.check_circle_outline,
          duration: const Duration(seconds: 2),
        );
        context.go('/formations');
      }
    } catch (e) {
      setState(() => _erreur = 'Email ou mot de passe incorrect');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      // Ajout d'une AppBar pour la flèche de retour
      appBar: AppBar(
        backgroundColor:
            Colors.transparent, // Transparent pour laisser voir le dégradé
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      extendBodyBehindAppBar: true, // Permet au contenu de passer sous l'AppBar
      // Fond de secours si le gradient met du temps à charger
      backgroundColor: AppColors.darkGradientStart,

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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.school_rounded,
                  size: 80,
                  color: Colors.white, // Logo en blanc pour le contraste
                ),
                const SizedBox(height: 16),
                const Text(
                  'Gestion Formation',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // Titre en blanc
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connectez-vous pour continuer',
                  style: TextStyle(
                    color: Colors.white70, // Sous-titre légèrement transparent
                  ),
                ),
                const SizedBox(height: 48),
                if (_erreur != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Text(
                      _erreur!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),

                // CHAMP EMAIL
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                  ), // Texte saisi en noir
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

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go('/mot-de-passe-oublie'),
                    child: const Text(
                      'Mot de passe oublie ?',
                      style: TextStyle(
                        color: Colors.white70, // Lien en blanc cassé
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                CustomButton(
                  label: 'Connexion',
                  icon: Icons.login_rounded,
                  isLoading: isLoading,
                  onPressed: _login,
                ),
                const SizedBox(height: 16),

                // Bouton inscription avec style adapté au fond sombre
                OutlinedButton(
                  onPressed: () => context.go('/register'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Inscription'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
