enum StatutInscription { enAttente, confirmee, annulee }

class ApprenantModel {
  final String id;
  final String apprenantId;
  final String formationId;
  final DateTime dateInscription;
  final List<String> sessionsPresent;
  final Map<String, double> notes;
  final StatutInscription statut;

  ApprenantModel({
    required this.id,
    required this.apprenantId,
    required this.formationId,
    required this.dateInscription,
    required this.sessionsPresent,
    required this.notes,
    required this.statut,
  });

  factory ApprenantModel.fromJson(Map<String, dynamic> json) => ApprenantModel(
    id: json['id'] ?? '',
    apprenantId: json['apprenantId'] ?? '',
    formationId: json['formationId'] ?? '',
    dateInscription: DateTime.parse(json['dateInscription']),
    sessionsPresent: List<String>.from(json['sessionsPresent'] ?? []),
    notes: Map<String, double>.from(json['notes'] ?? {}),
    statut: StatutInscription.values.firstWhere(
      (e) => e.name == json['statut'],
      orElse: () => StatutInscription.enAttente,
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'apprenantId': apprenantId,
    'formationId': formationId,
    'dateInscription': dateInscription.toIso8601String(),
    'sessionsPresent': sessionsPresent,
    'notes': notes,
    'statut': statut.name,
  };
}
