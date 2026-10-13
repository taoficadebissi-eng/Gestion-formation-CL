import '../core/supabase/supabase_config.dart';
import '../models/centre_model.dart';

class CentreService {
  final _db = SupabaseConfig.client;

  Stream<List<CentreModel>> ecouterCentresAdmin(String adminId) {
    return _db
        .from('centres')
        .stream(primaryKey: ['id'])
        .eq('admin_id', adminId)
        .map((rows) => rows.map(CentreModel.fromJson).toList());
  }

  Stream<CentreModel?> ecouterCentre(String centreId) {
    return _db
        .from('centres')
        .stream(primaryKey: ['id'])
        .eq('id', centreId)
        .map((rows) => rows.isEmpty ? null : CentreModel.fromJson(rows.first));
  }

  Future<String> creerCentre(CentreModel centre) async {
    final row = await _db.from('centres').insert(centre.toJson()).select().single();
    return row['id'] as String;
  }

  Future<void> modifierCentre(CentreModel centre) async {
    await _db.from('centres').update(centre.toJson()).eq('id', centre.id);
  }

  Future<void> desactiverCentre(String id) async {
    await _db.from('centres').update({'actif': false}).eq('id', id);
  }

  Future<void> supprimerCentre(String id) async {
    await _db.from('centres').delete().eq('id', id);
  }
}
