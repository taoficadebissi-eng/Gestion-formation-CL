import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../providers/auth_provider.dart';

class MotDePasseOublieScreen extends ConsumerStatefulWidget {
  const MotDePasseOublieScreen({super.key});

  @override
  ConsumerState<MotDePasseOublieScreen> createState() =>
      _MotDePasseOublieScreenState();
}

class _MotDePasseOublieScreenState
    extends ConsumerState<MotDePasseOublieScreen> {
  final _emailController = TextEditingController();
  String? _erreur;
  bool _emailEnvoye = false;

  // Style commun pour les TextField (Rectangle arrondi)
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppColors.surface, // Fond blanc pour le contraste
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
    _emailController.dispose();
    super.dispose();
  }

  bool _emailValide(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _reinitialiser() async {
    setState(() => _erreur = null);
    final email = _emailController.text.trim();

    if (!_emailValide(email)) {
      setState(() => _erreur = 'Veuillez entrer un e-mail valide');
      return;
    }

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .reinitialiserMotDePasse(email);
      if (mounted) {
        setState(() => _emailEnvoye = true);
      }
    } catch (e) {
      String message = 'Erreur lors de l envoi de l e-mail';
      if (e.toString().contains('user-not-found')) {
        message = 'Aucun compte associe a cet e-mail';
      } else if (e.toString().contains('invalid-email')) {
        message = 'Adresse e-mail invalide';
      }
      setState(() => _erreur = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.darkGradientStart,

      // AppBar TRANSPARENTE pour laisser voir le dégradé
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Mot de passe oublie',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent, // Fond transparent
        elevation: 0, // Pas d'ombre
        foregroundColor: Colors.white, // Icônes blanches
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
            child: _emailEnvoye
                ? _buildSuccessView()
                : _buildFormView(isLoading),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Icon(
          Icons.lock_reset_rounded,
          size: 56,
          color: Colors.white70, // Icône adaptée au fond sombre
        ),
        const SizedBox(height: 20),
        const Text(
          'Mot de passe oublie ?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white, // Titre en blanc
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Entrez votre adresse e-mail et nous vous enverrons un lien pour reinitialiser votre mot de passe.',
          style: TextStyle(color: Colors.white70, height: 1.5), // Texte clair
        ),
        const SizedBox(height: 32),
        if (_erreur != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error),
            ),
            child: Text(_erreur!, style: const TextStyle(color: Colors.white)),
          ),

        // CHAMP EMAIL MODIFIÉ
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: _buildInputDecoration(
            'Adresse e-mail',
            Icons.email_outlined,
          ),
        ),

        const SizedBox(height: 32),
        CustomButton(
          label: 'Envoyer le lien',
          icon: Icons.send_rounded,
          isLoading: isLoading,
          onPressed: _reinitialiser,
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Icon(
          Icons.check_circle_outline,
          size: 56,
          color: AppColors.success,
        ),
        const SizedBox(height: 20),
        const Text(
          'E-mail envoye !',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Un lien de reinitialisation a ete envoye a ${_emailController.text.trim()}. Verifiez votre boite de reception et suivez les instructions.',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        const SizedBox(height: 32),

        // Message important sur les spams - PLUS VISIBLE
        // J'ai gardé le style orange car il ressort bien même sur fond sombre
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange.shade900.withValues(
              alpha: 0.8,
            ), // Fond plus sombre pour le contraste
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade300, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade900,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Important',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Si vous ne recevez pas l e-mail dans votre boite de reception, verifiez votre dossier SPAM ou courrier indésirable.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'L e-mail peut mettre quelques minutes pour arriver.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        CustomButton(
          label: 'Retour a la connexion',
          icon: Icons.login_rounded,
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }
}
