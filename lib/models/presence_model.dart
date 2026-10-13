class PresenceModel {
  final String id;
  final String sessionId;
  final String formationId;
  final String centreId;
  final String apprenantId;
  final String apprenantNom;
  final bool present;
  final DateTime date;

  PresenceModel({
    required this.id,
    required this.sessionId,
    required this.formationId,
    required this.centreId,
    required this.apprenantId,
    required this.apprenantNom,
    required this.present,
    required this.date,
  });

  factory PresenceModel.fromJson(Map<String, dynamic> json) => PresenceModel(
    id: json['id'] ?? '',
    sessionId: json['session_id'] ?? '',
    formationId: json['formation_id'] ?? '',
    centreId: json['centre_id'] ?? '',
    apprenantId: json['apprenant_id'] ?? '',
    apprenantNom: json['apprenant_nom'] ?? '',
    present: json['present'] ?? false,
    date: DateTime.parse(json['date']),
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'formation_id': formationId,
    'centre_id': centreId,
    'apprenant_id': apprenantId,
    'apprenant_nom': apprenantNom,
    'present': present,
    'date': date.toIso8601String(),
  };

  // ✅ MÉTHODE OBLIGATOIRE POUR LA SÉCURITÉ MULTI-TENANT
  PresenceModel copyWith({
    String? id,
    String? sessionId,
    String? formationId,
    String? centreId,
    String? apprenantId,
    String? apprenantNom,
    bool? present,
    DateTime? date,
  }) {
    return PresenceModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      formationId: formationId ?? this.formationId,
      centreId: centreId ?? this.centreId,
      apprenantId: apprenantId ?? this.apprenantId,
      apprenantNom: apprenantNom ?? this.apprenantNom,
      present: present ?? this.present,
      date: date ?? this.date,
    );
  }
}
