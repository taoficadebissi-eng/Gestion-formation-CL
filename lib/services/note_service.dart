import 'dart:typed_data';
import '../core/supabase/supabase_config.dart';
import '../models/note_model.dart';

class NoteService {
  final _db = SupabaseConfig.client;

  Stream<List<NoteModel>> ecouterNotes(String formationId) {
    return _db
        .from('notes')
        .stream(primaryKey: ['id'])
        .eq('formation_id', formationId)
        .order('date_ajout', ascending: false)
        .map((rows) => rows.map(NoteModel.fromJson).toList());
  }

  Future<void> uploaderEtAjouter({
    required String formationId,
    required String nomFichier,
    required Uint8List bytes,
    required String uploadePar,
  }) async {
    final fileId = DateTime.now().millisecondsSinceEpoch.toString();
    final chemin = 'formations/$formationId/notes/${fileId}_$nomFichier';

    await _db.storage.from('notes').uploadBinary(chemin, bytes);

    final note = NoteModel(
      id: '',
      formationId: formationId,
      nomFichier: nomFichier,
      url: chemin,
      uploadePar: uploadePar,
      dateAjout: DateTime.now(),
    );
    await _db.from('notes').insert(note.toJson());
  }

  /// URL signée temporaire (1h) pour ouvrir/télécharger le fichier : le
  /// bucket est privé, pas d'URL publique permanente.
  Future<String> obtenirUrlOuverture(String chemin) async {
    return await _db.storage.from('notes').createSignedUrl(chemin, 3600);
  }

  Future<void> supprimer(String noteId, String chemin) async {
    await _db.storage.from('notes').remove([chemin]);
    await _db.from('notes').delete().eq('id', noteId);
  }
}
