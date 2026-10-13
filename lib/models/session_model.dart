enum StatutSession { planifiee, enCours, terminee }

class SessionModel {
  final String id;
  final String formationId;
  final String centreId;
  final String titre;
  final String details;
  final DateTime date;
  final String heureDebut;
  final String heureFin;
  final String salle;
  final StatutSession statut;

  SessionModel({
    required this.id,
    required this.formationId,
    required this.centreId,
    required this.titre,
    required this.details,
    required this.date,
    required this.heureDebut,
    required this.heureFin,
    required this.salle,
    required this.statut,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) => SessionModel(
    id: json['id'] ?? '',
    formationId: json['formation_id'] ?? '',
    centreId: json['centre_id'] ?? '',
    titre: json['titre'] ?? '',
    details: json['details'] ?? '',
    date: DateTime.parse(json['date']),
    heureDebut: json['heure_debut'] ?? '',
    heureFin: json['heure_fin'] ?? '',
    salle: json['salle'] ?? '',
    statut: StatutSession.values.firstWhere(
      (e) => e.name == json['statut'],
      orElse: () => StatutSession.planifiee,
    ),
  );

  Map<String, dynamic> toJson() => {
    'formation_id': formationId,
    'centre_id': centreId,
    'titre': titre,
    'details': details,
    'date': date.toIso8601String(),
    'heure_debut': heureDebut,
    'heure_fin': heureFin,
    'salle': salle,
    'statut': statut.name,
  };
  // ✅ AJOUT OBLIGATOIRE DANS SessionModel
  SessionModel copyWith({
    String? id,
    String? formationId,
    String? centreId,
    String? titre,
    String? details,
    DateTime? date,
    String? heureDebut,
    String? heureFin,
    String? salle,
    StatutSession? statut,
  }) {
    return SessionModel(
      id: id ?? this.id,
      formationId: formationId ?? this.formationId,
      centreId: centreId ?? this.centreId,
      titre: titre ?? this.titre,
      details: details ?? this.details,
      date: date ?? this.date,
      heureDebut: heureDebut ?? this.heureDebut,
      heureFin: heureFin ?? this.heureFin,
      salle: salle ?? this.salle,
      statut: statut ?? this.statut,
    );
  }
}
