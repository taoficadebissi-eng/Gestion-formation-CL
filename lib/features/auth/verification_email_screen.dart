import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/blurred_toast.dart';

/// Écran affiché tant que l'e-mail de l'utilisateur connecté n'est pas
/// vérifié. Il contrôle périodiquement la vérification ; dès qu'elle est
/// faite, le routeur redirige vers l'espace de l'utilisateur.
class VerificationEmailScreen extends ConsumerStatefulWidget {
  const VerificationEmailScreen({super.key});

  @override
  ConsumerState<VerificationEmailScreen> createState() =>
      _VerificationEmailScreenState();
}

class _VerificationEmailScreenState
    extends ConsumerState<VerificationEmailScreen> {
  static const _delaiRenvoi = 60;

  Timer? _sondage;
  Timer? _compteARebours;
  int _secondesRestantes = 0;
  bool _verificationEnCours = false;
  bool _premierEnvoiFait = false;

  @override
  void initState() {
    super.initState();
    _sondage = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _verifier(silencieux: true),
    );
  }

  @override
  void dispose() {
    _sondage?.cancel();
    _compteARebours?.cancel();
    super.dispose();
  }

  Future<void> _verifier({bool silencieux = false}) async {
    if (_verificationEnCours) return;
    _verificationEnCours = true;
    try {
      final verifie = await ref
          .read(authNotifierProvider.notifier)
          .verifierEmail();
      if (!verifie && !silencieux && mounted) {
        BlurredToast.show(
          context,
          "Pas encore verifie. Ouvrez le lien recu par e-mail.",
          icon: Icons.info_outline,
        );
      }
    } catch (e) {
      if (!silencieux && mounted) {
        final invalide = e.toString().contains('invitation_invalide');
        BlurredToast.show(
          context,
          invalide
              ? "Code d'invitation invalide ou deja utilise"
              : 'Erreur : $e',
          icon: Icons.error_outline,
        );
      }
    } finally {
      _verificationEnCours = false;
    }
  }

  Future<void> _renvoyer() async {
    try {
      await ref.read(authNotifierProvider.notifier).renvoyerVerificationEmail();
      _premierEnvoiFait = true;
      if (mounted) {
        BlurredToast.show(
          context,
          'E-mail de verification envoye',
          icon: Icons.mark_email_read_outlined,
        );
      }
      setState(() => _secondesRestantes = _delaiRenvoi);
      _compteARebours?.cancel();
      _compteARebours = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_secondesRestantes <= 1) {
          t.cancel();
          if (mounted) setState(() => _secondesRestantes = 0);
        } else if (mounted) {
          setState(() => _secondesRestantes--);
        }
      });
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        BlurredToast.show(
          context,
          e.code == 'too-many-requests'
              ? 'Trop de demandes, reessayez dans quelques minutes'
              : 'Envoi impossible : ${e.code}',
          icon: Icons.error_outline,
        );
      }
    }
  }

  Future<void> _deconnecter() async {
    await ref.read(authNotifierProvider.notifier).deconnexion();
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authStateProvider).value?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.darkGradientStart,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.darkGradientStart,
              AppColors.darkGradientMid,
              AppColors.darkGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 72,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Verifiez votre e-mail',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Un lien de verification a ete envoye a\n$email.\n'
                      'Cliquez dessus (pensez aux spams), puis revenez ici : '
                      'la page se met a jour toute seule.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _verifier(),
                        child: const Text("J'ai verifie mon e-mail"),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _secondesRestantes > 0 ? null : _renvoyer,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _secondesRestantes > 0
                              ? 'Renvoyer ($_secondesRestantes s)'
                              : (_premierEnvoiFait
                                    ? "Renvoyer l'e-mail"
                                    : "Envoyer l'e-mail de verification"),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _deconnecter,
                      child: Text(
                        'Se deconnecter',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
