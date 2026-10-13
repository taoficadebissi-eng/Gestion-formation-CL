import 'package:cloud_firestore/cloud_firestore.dart';

/// Raccourci vers l'instance Firestore partagée par tous les services.
FirebaseFirestore get firestore => FirebaseFirestore.instance;

/// E-mail du super-admin. Le compte doit exister dans Firebase Auth avec
/// l'e-mail vérifié : les règles Firestore appliquent la même vérification,
/// cette constante ne sert qu'à orienter la navigation.
const String superAdminEmail = 'taoficadebissi@gmail.com';

extension DocumentJson on DocumentSnapshot<Map<String, dynamic>> {
  /// Données du document + son id, au format attendu par les `fromJson`.
  Map<String, dynamic>? toJsonAvecId() {
    final donnees = data();
    if (donnees == null) return null;
    return {...donnees, 'id': id};
  }
}

extension QueryJson on QuerySnapshot<Map<String, dynamic>> {
  List<Map<String, dynamic>> toJsonListe() =>
      docs.map((d) => {...d.data(), 'id': d.id}).toList();
}
