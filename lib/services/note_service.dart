import '../core/firebase/firestore_helpers.dart';
import '../models/note_model.dart';

/// Documents de cours d'une formation. Firebase Storage n'étant pas
/// disponible sur le plan gratuit, une note est un lien (https) vers un
/// document hébergé ailleurs (Google Drive, OneDrive, etc.).
class NoteService {
  final _col = firestore.collection('notes');

  Stream<List<NoteModel>> ecouterNotes(String formationId) {
    return _col.where('formation_id', isEqualTo: formationId).snapshots().map((
      s,
    ) {
      final liste = s.toJsonListe().map(NoteModel.fromJson).toList();
      liste.sort((a, b) => b.dateAjout.compareTo(a.dateAjout));
      return liste;
    });
  }

  Future<void> ajouterLien({
    required String formationId,
    required String nomFichier,
    required String url,
    required String uploadePar,
  }) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasAuthority || uri.scheme != 'https') {
      throw Exception('Le lien doit commencer par https://');
    }
    final note = NoteModel(
      id: '',
      formationId: formationId,
      nomFichier: nomFichier.trim(),
      url: uri.toString(),
      uploadePar: uploadePar,
      dateAjout: DateTime.now(),
    );
    await _col.add(note.toJson());
  }

  Future<void> supprimer(String noteId) async {
    await _col.doc(noteId).delete();
  }
}
