import '../core/supabase/supabase_config.dart';
import '../models/user_model.dart';

class UserService {
  final _db = SupabaseConfig.client;

  // Écouter un utilisateur spécifique
  Stream<UserModel?> ecouterUtilisateur(String userId) {
    return _db
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) => rows.isEmpty ? null : UserModel.fromJson(rows.first));
  }

  // Écouter les utilisateurs par rôle dans un centre
  Stream<List<UserModel>> ecouterUtilisateursParRole(
    String role,
    String centreId,
  ) {
    return _db
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('centre_id', centreId)
        .map(
          (rows) => rows
              .where((row) => row['role'] == role)
              .map(UserModel.fromJson)
              .toList(),
        );
  }

  // Écouter tous les utilisateurs d'un centre
  Stream<List<UserModel>> ecouterTousUtilisateurs(String centreId) {
    return _db
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('centre_id', centreId)
        .map((rows) => rows.map(UserModel.fromJson).toList());
  }

  // Marquer le premier login comme effectué
  Future<void> marquerPremierLoginEffectue(String userId) async {
    await _db.from('profiles').update({'is_first_login': false}).eq('id', userId);
  }

  // Marquer le mot de passe comme changé (alias)
  Future<void> marquerMotDePasseChange(String userId) async {
    await _db.from('profiles').update({'is_first_login': false}).eq('id', userId);
  }

  // Forcer marquer comme connecté (alias)
  Future<void> forcerMarquerCommeConnecte(String userId) async {
    await _db.from('profiles').update({'is_first_login': false}).eq('id', userId);
  }

  // Rafraîchir le profil
  Future<void> rafraichirProfil(String userId) async {
    await _db.from('profiles').select().eq('id', userId).maybeSingle();
  }

  // Compter les apprenants
  Stream<int> compterApprenants(String centreId) {
    return _db
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('centre_id', centreId)
        .map((rows) => rows.where((row) => row['role'] == 'apprenant').length);
  }

  // Compter les formateurs
  Stream<int> compterFormateurs(String centreId) {
    return _db
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('centre_id', centreId)
        .map((rows) => rows.where((row) => row['role'] == 'formateur').length);
  }
}
