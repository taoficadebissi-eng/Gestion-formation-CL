import 'package:supabase_flutter/supabase_flutter.dart';

/// Config du projet Supabase (remplace Firebase Auth + Firestore pour les
/// données de Gestion Formation — voir NOTES_AUDIT.md et
/// supabase/migrations/0001_foundations.sql).
///
/// La clé "anon" est faite pour être embarquée côté client : toute la
/// protection réelle des données repose sur les policies RLS Postgres,
/// jamais sur le secret de cette clé.
class SupabaseConfig {
  static const String url = 'https://xuvvqkwjkxnyafrqxgta.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh1dnZxa3dqa3hueWFmcnF4Z3RhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc5OTMxOTIsImV4cCI6MjEwMzU2OTE5Mn0.6JzLgSIwzlH1OkFmtlrwL3vtRlY79awGQRa-IDUUmRs';

  static Future<void> init() async {
    await Supabase.initialize(url: url, publishableKey: anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;

  /// Instance Supabase secondaire, isolée de la session courante.
  ///
  /// Utilisée uniquement pour la création de comptes formateur/apprenant
  /// par un admin déjà connecté : signUp() sur le client principal
  /// remplacerait la session admin par celle du nouveau compte. Chaque appel
  /// crée un client Postgrest/GoTrue indépendant, jeté après usage — même
  /// logique que la "secondary Firebase app" précédemment utilisée avec
  /// Firebase Auth.
  ///
  /// `authFlowType: implicit` est nécessaire ici : le flow PKCE (par défaut)
  /// exige un `pkceAsyncStorage`, que seul `Supabase.initialize()` fournit
  /// pour le client principal. Sans lui, `signUp()` plante sur un null-check
  /// interne à `gotrue` — ce qui, avant ce correctif, faisait échouer la
  /// création du compte ET déconnectait l'admin (l'exception survenait
  /// avant l'écriture du profil, et se propageait jusqu'au `catch` de
  /// l'écran sans jamais avoir créé de session secondaire à nettoyer).
  /// Le flow implicite n'a pas besoin de code verifier persistant et
  /// convient parfaitement à ce client jetable, utilisé une seule fois.
  static SupabaseClient createSecondaryClient() {
    return SupabaseClient(
      url,
      anonKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
      ),
    );
  }
}
