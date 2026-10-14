import 'package:cloud_firestore/cloud_firestore.dart';
import 'cours_gratuit_model.dart';

/// Un cours trouvé par le programme de veille, en attente de validation.
class PropositionCours {
  final String id;
  final CoursGratuit cours;
  final String sourceNom;
  final String urlSource;
  final double confiance;
  final String remarques;
  final DateTime? dateProposition;

  const PropositionCours({
    required this.id,
    required this.cours,
    required this.sourceNom,
    required this.urlSource,
    required this.confiance,
    required this.remarques,
    required this.dateProposition,
  });

  factory PropositionCours.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PropositionCours(
      id: doc.id,
      cours: CoursGratuit.fromFirestore(doc),
      sourceNom: (data['sourceNom'] as String?) ?? '',
      urlSource: (data['urlSource'] as String?) ?? '',
      confiance: (data['confiance'] as num?)?.toDouble() ?? 0,
      remarques: (data['remarques'] as String?) ?? '',
      dateProposition: (data['dateProposition'] as Timestamp?)?.toDate(),
    );
  }

  bool get aVerifier => remarques.trim().isNotEmpty || confiance < 0.7;
}
