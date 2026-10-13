import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Imports Auth & Admin
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/changer_mot_de_passe_screen.dart';
import '../features/auth/mot_de_passe_oublie_screen.dart';
import '../features/auth/super_admin_screen.dart';
import '../features/admin/admin_shell_screen.dart';
import '../features/admin/gestion_users_screen.dart';
import '../features/admin/creer_utilisateur_screen.dart';
import '../features/admin/succes_creation_screen.dart';

// Imports Centre & Formations
import '../features/centre/creer_centre_screen.dart';
import '../features/centre/selectionner_centre_screen.dart';
import '../features/formations/catalogue_screen.dart';
import '../features/formations/ajouter_formation_screen.dart';
import '../features/formations/detail_formation_screen.dart';
import '../features/formations/modifier_formation_screen.dart';
import '../features/formations/inscrits_screen.dart';
import '../features/formations/formateur_shell_screen.dart';
import '../features/planning/sessions_screen.dart';
import '../features/planning/ajouter_session_screen.dart';
import '../features/planning/calendar_screen.dart';
import '../features/suivi/apprenant_shell_screen.dart';

// Imports Cours Publics & Super Admin
// Réactiver AccueilPublicScreen() sur la route '/' pour remettre la
// vitrine CoursLibre en ligne.
// ignore: unused_import
import '../features/cours_publics/screens/accueil_public_screen.dart';
import '../features/cours_publics/screens/detail_cours_screen.dart';
import '../features/cours_publics/models/cours_gratuit_model.dart';
import '../features/auth/gestion_cours_screen.dart'; // Import corrigé vers le bon dossier
import '../features/auth/liste_cours_screen.dart';

// Models & Providers
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/centre_provider.dart';
import '../providers/formation_provider.dart';
import '../providers/user_provider.dart';

/// Convertit les changements des providers d'auth/profil/centres en
/// notifications pour GoRouter (`refreshListenable`), afin qu'un seul
/// [GoRouter] soit créé pour toute la durée de vie de l'app.
///
/// Piège corrigé ici : l'ancienne version de ce fichier exposait
/// `AppRouter.createRouter(user:, isLoading:, centres:)`, appelée à
/// l'intérieur de `build()` dans `main.dart`. Comme ces paramètres
/// changeaient à chaque évènement realtime Supabase (assez fréquents), un
/// **nouveau** `GoRouter` était recréé à chaque fois — ce qui réinitialise
/// toute la pile de navigation à `initialLocation` et relance `redirect`
/// avec l'état du moment, parfois transitoire (ex: un `INSERT` realtime sur
/// `profiles` pendant la création d'un utilisateur par l'admin pouvait faire
/// atterrir l'admin sur `/changer-mot-de-passe`). Un seul routeur, notifié
/// via `refreshListenable`, conserve la pile de navigation et ne fait
/// évaluer `redirect` qu'au bon moment, sans jamais la recréer.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(userProfileProvider, (_, _) => notifyListeners());
    ref.listen(centresDuAdminProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      final authState = ref.read(authStateProvider);
      final userProfileAsync = ref.read(userProfileProvider);
      final centresAsync = ref.read(centresDuAdminProvider);

      final isLoading =
          authState.isLoading ||
          userProfileAsync.isLoading ||
          centresAsync.isLoading;
      final user = userProfileAsync.value;
      final centres = centresAsync.value ?? [];

      // NOTE : '/admin/gestion-cours' est publique au sens du router car le
      // super-admin n'utilise pas Firebase Auth (accès caché par geste dans
      // l'app, meme logique que '/super-admin'). La protection reelle de
      // cette page repose sur les Firestore Security Rules et le fait que
      // l'URL n'est pas exposee/linkee publiquement.
      final isPublicRoute =
          loc == '/login' ||
          loc == '/register' ||
          loc == '/mot-de-passe-oublie' ||
          loc == '/super-admin' ||
          loc == '/admin/gestion-cours' ||
          loc == '/admin/liste-cours' ||
          loc.startsWith('/cours/');

      final isLoggedIn = user != null;
      // '/' affiche temporairement LoginScreen (vitrine CoursLibre
      // désactivée) : elle doit se comporter comme une route
      // d'authentification, pas comme la route publique qu'elle était.
      final isAuthRoute =
          loc == '/' ||
          loc == '/login' ||
          loc == '/register' ||
          loc == '/mot-de-passe-oublie' ||
          loc == '/connexion';

      final isCentreRoute =
          loc == '/centre/creer' || loc == '/centre/selectionner';

      final isChangePasswordRoute = loc == '/changer-mot-de-passe';
      final isSuccesCreationRoute = loc == '/admin/users/succes';
      final isSplash = loc == '/splash';

      if (isLoading) {
        return loc == '/splash' ? null : '/splash';
      }

      if (isSplash && !isLoading) {
        if (!isLoggedIn) return '/';
      }

      if (isPublicRoute) return null;

      if (!isLoggedIn && !isAuthRoute) return '/connexion';

      if (isLoggedIn && user.role == UserRole.admin && isChangePasswordRoute) {
        if (centres.isEmpty) return '/centre/creer';
        if (centres.length == 1) return '/admin/dashboard';
        return '/centre/selectionner';
      }

      if (isLoggedIn &&
          user.mustChangePassword &&
          !isChangePasswordRoute &&
          !isAuthRoute &&
          !isSuccesCreationRoute &&
          user.role != UserRole.admin) {
        return '/changer-mot-de-passe';
      }

      if (isLoggedIn && (isAuthRoute || isSplash)) {
        if (user.role == UserRole.admin) {
          if (centres.isEmpty) return '/centre/creer';
          if (centres.length == 1) return '/admin/dashboard';
          return '/centre/selectionner';
        }
        if (user.role == UserRole.formateur) return '/dashboard-formateur';
        if (user.role == UserRole.apprenant) return '/espace-apprenant';
      }

      // Le routeur n'étant désormais créé qu'une seule fois (voir plus haut),
      // rester sur '/centre/creer' ou '/centre/selectionner' pendant que
      // `centresDuAdminProvider` rattrape la création (le fetch initial du
      // stream réaltime a pu être vide, la création vient d'arriver) ne
      // déclenche plus de redirection automatique : sans cette règle, le
      // premier centre créé par un admin laissait l'app bloquée sur l'écran
      // de création une fois le centre effectivement enregistré.
      if (isLoggedIn &&
          user.role == UserRole.admin &&
          isCentreRoute &&
          centres.isNotEmpty) {
        if (centres.length == 1) return '/admin/dashboard';
        return '/centre/selectionner';
      }

      if (isLoggedIn &&
          user.role == UserRole.admin &&
          !isCentreRoute &&
          !isSuccesCreationRoute &&
          !isChangePasswordRoute) {
        if (centres.isEmpty) return '/centre/creer';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        // TEMPORAIRE (démo client Gestion Formation) : vitrine CoursLibre
        // désactivée, '/' pointe vers la connexion. Remettre
        // `AccueilPublicScreen()` pour réactiver la vitrine.
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/connexion',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/mot-de-passe-oublie',
        builder: (context, state) => const MotDePasseOublieScreen(),
      ),
      GoRoute(
        path: '/super-admin',
        builder: (context, state) => const SuperAdminScreen(),
      ),
      GoRoute(
        path: '/changer-mot-de-passe',
        builder: (context, state) => const ChangerMotDePasseScreen(),
      ),
      GoRoute(
        path: '/centre/creer',
        builder: (context, state) => const CreerCentreScreen(),
      ),
      GoRoute(
        path: '/centre/selectionner',
        builder: (context, state) => const SelectionnerCentreScreen(),
      ),
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminShellScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const GestionUsersScreen(),
      ),
      GoRoute(
        path: '/admin/users/creer',
        builder: (context, state) => const CreerUtilisateurScreen(),
      ),
      GoRoute(
        path: '/admin/users/succes',
        builder: (context, state) {
          final extra = state.extra as Map<String, String>? ?? {};
          return SuccesCreationScreen(
            prenom: extra['prenom'] ?? '',
            nom: extra['nom'] ?? '',
            email: extra['email'] ?? '',
            motDePasse: extra['motDePasse'] ?? '',
            role: extra['role'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/dashboard-formateur',
        builder: (context, state) => const FormateurShellScreen(),
      ),
      GoRoute(
        path: '/espace-apprenant',
        builder: (context, state) => const ApprenantShellScreen(),
      ),
      GoRoute(
        path: '/formations',
        builder: (context, state) => const CatalogueScreen(),
      ),
      GoRoute(
        path: '/formations/ajouter',
        builder: (context, state) => const AjouterFormationScreen(),
      ),
      GoRoute(
        path: '/formations/:id',
        builder: (context, state) =>
            DetailFormationScreen(formationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/formations/:id/modifier',
        builder: (context, state) {
          final formationId = state.pathParameters['id']!;
          return Consumer(
            builder: (context, ref, child) {
              final formationsAsync = ref.watch(formationsProvider);
              return formationsAsync.when(
                loading: () => const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) =>
                    Scaffold(body: Center(child: Text('Erreur : $e'))),
                data: (formations) {
                  final formation = formations
                      .where((f) => f.id == formationId)
                      .firstOrNull;
                  if (formation == null) {
                    return Scaffold(
                      appBar: AppBar(
                        title: const Text('Formation introuvable'),
                      ),
                      body: const Center(
                        child: Text('Cette formation n existe plus'),
                      ),
                    );
                  }
                  return ModifierFormationScreen(formation: formation);
                },
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/formations/:id/inscrits',
        builder: (context, state) => InscritsScreen(
          formationId: state.pathParameters['id']!,
          formationTitre: 'Inscrits',
        ),
      ),
      GoRoute(
        path: '/formations/:id/sessions',
        builder: (context, state) => SessionsScreen(
          formationId: state.pathParameters['id']!,
          formationTitre: 'Sessions',
        ),
      ),
      GoRoute(
        path: '/formations/:id/sessions/ajouter',
        builder: (context, state) =>
            AjouterSessionScreen(formationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/calendrier',
        builder: (context, state) => const CalendarScreen(),
      ),
      // ROUTES SUPER-ADMIN POUR LES COURS GRATUITS
      GoRoute(
        path: '/admin/gestion-cours',
        builder: (context, state) => const GestionCoursScreen(),
      ),
      GoRoute(
        path: '/admin/liste-cours',
        builder: (context, state) => const ListeCoursScreen(),
      ),
      GoRoute(
        path: '/cours/:id',
        builder: (context, state) {
          final cours = state.extra as CoursGratuit?;
          if (cours == null) {
            // Accès direct à l'URL sans passer par la carte (extra vide) :
            // on renvoie vers la connexion plutôt que de crasher.
            return const LoginScreen();
          }
          return DetailCoursScreen(cours: cours);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page introuvable: ${state.error}')),
    ),
  );
});
