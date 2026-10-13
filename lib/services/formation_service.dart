import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase/supabase_config.dart';
import '../models/formation_model.dart';

class FormationService {
  final _db = SupabaseConfig.client;

  Stream<List<Formation>> ecouterFormations(String centreId) {
    return _db
        .from('formations')
        .stream(primaryKey: ['id'])
        .eq('centre_id', centreId)
        .order('date_creation', ascending: false)
        .map((rows) => rows.map(Formation.fromJson).toList());
  }

  Future<Formation> ajouterFormation(Formation formation) async {
    final row = await _db
        .from('formations')
        .insert(formation.toJson())
        .select()
        .single();
    return Formation.fromJson(row);
  }

  Future<void> modifierFormation(Formation formation) async {
    await _db.from('formations').update(formation.toJson()).eq('id', formation.id);
  }

  Future<void> supprimerFormation(String id) async {
    await _db.from('formations').delete().eq('id', id);
  }

  /// Upload l'image de couverture (Phase 7) et renvoie son URL publique
  /// (bucket "formations-images" public — pas besoin d'URL signée, à la
  /// différence des notes de cours).
  Future<String> uploaderImage({
    required String formationId,
    required String nomFichier,
    required Uint8List bytes,
  }) async {
    final fileId = DateTime.now().millisecondsSinceEpoch.toString();
    final chemin = 'formations/$formationId/cover_$fileId-$nomFichier';
    await _db.storage.from('formations-images').uploadBinary(
          chemin,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _db.storage.from('formations-images').getPublicUrl(chemin);
  }
}
