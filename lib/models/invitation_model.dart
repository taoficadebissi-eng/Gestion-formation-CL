import 'package:cloud_firestore/cloud_firestore.dart';

/// Un code d'invitation tel que lu dans Firestore. La lecture est tolérante :
/// la collection peut contenir d'anciens codes (autres noms de champs, autres
/// types) qui ne doivent jamais empêcher l'affichage de la liste.
class InvitationModel {
  final String id;
  final String token;
  final bool utilise;
  final DateTime? date;

  const InvitationModel({
    required this.id,
    required this.token,
    required this.utilise,
    required this.date,
  });

  /// Seul un code dont l'identifiant du document est le code lui-même peut
  /// servir à l'inscription (les règles Firestore l'exigent).
  bool get valide => id == token;
  bool get disponible => valide && !utilise;

  static InvitationModel depuis(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => depuisMap(doc.id, doc.data());

  static InvitationModel depuisMap(String id, Map<String, dynamic> d) {
    final token = d['token'];
    return InvitationModel(
      id: id,
      token: token is String && token.isNotEmpty ? token : id,
      utilise: d['utilise'] == true,
      date: _lireDate(d['date_creation'] ?? d['dateCreation']),
    );
  }

  static DateTime? _lireDate(Object? valeur) {
    if (valeur is Timestamp) return valeur.toDate();
    if (valeur is String) return DateTime.tryParse(valeur);
    return null;
  }
}
