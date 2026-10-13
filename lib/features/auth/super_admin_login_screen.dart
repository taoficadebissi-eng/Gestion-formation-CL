import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/firebase/firestore_helpers.dart';
import '../../providers/auth_provider.dart';

/// Authentification du super-admin, atteinte par 10 appuis sur le logo de la
/// page de connexion. Le geste ne protège rien en lui-même : l'accès repose
/// sur le compte (e-mail + mot de passe, e-mail vérifié) et sur les règles
/// Firestore. Un autre compte est refusé et déconnecté.
class SuperAdminLoginScreen extends ConsumerStatefulWidget {
  const SuperAdminLoginScreen({super.key});

  @override
  ConsumerState<SuperAdminLoginScreen> createState() =>
      _SuperAdminLoginScreenState();
}

class _SuperAdminLoginScreenState extends ConsumerState<SuperAdminLoginScreen> {
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _masque = true;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _email.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _connecter() async {
    final email = _email.text.trim().toLowerCase();
    if (email.isEmpty || _motDePasse.text.isEmpty) {
      setState(() => _erreur = 'Saisissez votre e-mail et votre mot de passe');
      return;
    }
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .connexion(email, _motDePasse.text);
      if (email != superAdminEmail) {
        await ref.read(authNotifierProvider.notifier).deconnexion();
        if (mounted) setState(() => _erreur = 'Acces refuse');
      }
      // Compte super-admin : le routeur redirige vers /super-admin (ou vers
      // la verification de l'e-mail si elle n'est pas encore faite).
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () => _erreur = e.code == 'too-many-requests'
              ? 'Trop de tentatives, reessayez dans quelques minutes'
              : 'Identifiants incorrects',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _erreur = 'Identifiants incorrects');
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGradientStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/login'),
        ),
      ),
      extendBodyBehindAppBar: true,
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
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      size: 64,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Espace Super Admin',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: _decoration(
                        'Adresse e-mail',
                        Icons.mail_outline,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _motDePasse,
                      obscureText: _masque,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _connecter(),
                      decoration:
                          _decoration(
                            'Mot de passe',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _masque
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setState(() => _masque = !_masque),
                            ),
                          ),
                    ),
                    if (_erreur != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _erreur!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFFB4AB)),
                      ),
                    ],
                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: _enCours ? null : _connecter,
                      child: _enCours
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Se connecter'),
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

  InputDecoration _decoration(String label, IconData icone) {
    return InputDecoration(
      hintText: label,
      prefixIcon: Icon(icone),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}
