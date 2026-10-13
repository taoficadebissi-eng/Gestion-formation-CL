import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/supabase/supabase_config.dart';
import 'router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase reste utilisé pour la vitrine publique CoursLibre
  // (cours_gratuits, compteur de visiteurs), hors périmètre de la refonte.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Supabase remplace Firebase Auth + Firestore pour Gestion Formation
  // (users, centres, formations, sessions, inscriptions, presences,
  // invitations) — voir NOTES_AUDIT.md.
  await SupabaseConfig.init();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Le routeur est créé une seule fois (routerProvider) et notifié des
    // changements d'auth/profil/centres via refreshListenable, plutôt que
    // recréé à chaque changement — voir le commentaire dans app_router.dart.
    // L'écran de chargement/erreur initial est géré par le routeur lui-même
    // (route '/splash'), donc plus besoin de `.when()` ici.
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Gestion Formation',
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
