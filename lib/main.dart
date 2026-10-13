import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
