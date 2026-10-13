import '../../../core/firebase/firestore_helpers.dart';
import '../models/cours_gratuit_model.dart';

/// Cours gratuits affichés sur la vitrine publique CoursLibre (projet
/// séparé). Les règles Firestore réservent l'écriture au super-admin.
class CoursAdminService {
  final _col = firestore.collection('cours_gratuits');

  Stream<List<CoursGratuit>> ecouterTous() {
    return _col.snapshots().map((s) {
      final liste = s.docs.map(CoursGratuit.fromFirestore).toList();
      liste.sort((a, b) {
        final ordreA = a.ordreAffichage;
        final ordreB = b.ordreAffichage;
        if (ordreA != null && ordreB != null && ordreA != ordreB) {
          return ordreA.compareTo(ordreB);
        }
        if (ordreA != null && ordreB == null) return -1;
        if (ordreA == null && ordreB != null) return 1;
        return (b.dateAjout ?? DateTime(2000)).compareTo(
          a.dateAjout ?? DateTime(2000),
        );
      });
      return liste;
    });
  }

  Future<void> ajouter(CoursGratuit cours) async {
    await _col.add(cours.toFirestore(isNew: true));
  }

  Future<void> modifier(CoursGratuit cours) async {
    await _col.doc(cours.id).update(cours.toFirestore());
  }

  Future<void> supprimer(String id) async {
    await _col.doc(id).delete();
  }

  /// Nombre total de visiteurs (compteur incrémenté par la vitrine publique,
  /// une fois par appareil et par jour).
  Stream<int> ecouterVisiteurs() {
    return firestore
        .collection('compteur')
        .doc('visiteurs')
        .snapshots()
        .map((doc) => (doc.data()?['total'] as num?)?.toInt() ?? 0);
  }
}
