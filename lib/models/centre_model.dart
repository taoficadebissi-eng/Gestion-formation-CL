class CentreModel {
  final String id;
  final String nom;
  final String adminId;
  final String ville;
  final String pays;
  final DateTime dateCreation;
  final bool actif;

  CentreModel({
    required this.id,
    required this.nom,
    required this.adminId,
    required this.ville,
    required this.pays,
    required this.dateCreation,
    this.actif = true,
  });

  CentreModel copyWith({
    String? id,
    String? nom,
    String? adminId,
    String? ville,
    String? pays,
    DateTime? dateCreation,
    bool? actif,
  }) {
    return CentreModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      adminId: adminId ?? this.adminId,
      ville: ville ?? this.ville,
      pays: pays ?? this.pays,
      dateCreation: dateCreation ?? this.dateCreation,
      actif: actif ?? this.actif,
    );
  }

  factory CentreModel.fromJson(Map<String, dynamic> json) => CentreModel(
    id: json['id'] ?? '',
    nom: json['nom'] ?? '',
    adminId: json['admin_id'] ?? '',
    ville: json['ville'] ?? '',
    pays: json['pays'] ?? '',
    dateCreation: DateTime.parse(json['date_creation']),
    actif: json['actif'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'nom': nom,
    'admin_id': adminId,
    'ville': ville,
    'pays': pays,
    'date_creation': dateCreation.toIso8601String(),
    'actif': actif,
  };
}
