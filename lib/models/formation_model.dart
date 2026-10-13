class Formation {
  final String id;
  final String titre;
  final String description;
  final String formateurId;
  final String formateurNom;
  final int nombreSessions;
  final String niveau;
  final DateTime dateCreation;
  final DateTime dateDebut;
  final DateTime dateFin;
  final String centreId;
  final String? prerequisId;
  final double fraisTotal;
  final String? imageUrl;

  Formation({
    required this.id,
    required this.titre,
    required this.description,
    required this.formateurId,
    required this.formateurNom,
    required this.nombreSessions,
    required this.niveau,
    required this.dateCreation,
    required this.dateDebut,
    required this.dateFin,
    required this.centreId,
    this.prerequisId,
    this.fraisTotal = 0,
    this.imageUrl,
  });

  factory Formation.fromJson(Map<String, dynamic> json) {
    return Formation(
      id: json['id'] ?? '',
      titre: json['titre'] ?? '',
      description: json['description'] ?? '',
      formateurId: json['formateur_id'] ?? '',
      formateurNom: json['formateur_nom'] ?? '',
      nombreSessions: json['nombre_sessions'] ?? 0,
      niveau: json['niveau'] ?? 'Debutant',
      dateCreation: DateTime.parse(json['date_creation']),
      dateDebut: json['date_debut'] != null
          ? DateTime.parse(json['date_debut'])
          : DateTime.now(),
      dateFin: json['date_fin'] != null
          ? DateTime.parse(json['date_fin'])
          : DateTime.now(),
      centreId: json['centre_id'] ?? '',
      prerequisId: json['prerequis_id'],
      fraisTotal: (json['frais_total'] as num?)?.toDouble() ?? 0,
      imageUrl: json['image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'titre': titre,
      'description': description,
      'formateur_id': formateurId.isEmpty ? null : formateurId,
      'formateur_nom': formateurNom,
      'nombre_sessions': nombreSessions,
      'niveau': niveau,
      'date_creation': dateCreation.toIso8601String(),
      'date_debut': dateDebut.toIso8601String(),
      'date_fin': dateFin.toIso8601String(),
      'centre_id': centreId,
      'prerequis_id': prerequisId != null && prerequisId!.isNotEmpty
          ? prerequisId
          : null,
      'frais_total': fraisTotal,
      'image_url': imageUrl,
    };
  }

  // ✅ MÉTHODE OBLIGATOIRE POUR LA SÉCURITÉ MULTI-TENANT
  Formation copyWith({
    String? id,
    String? titre,
    String? description,
    String? formateurId,
    String? formateurNom,
    int? nombreSessions,
    String? niveau,
    DateTime? dateCreation,
    DateTime? dateDebut,
    DateTime? dateFin,
    String? centreId,
    String? prerequisId,
    bool clearPrerequisId = false,
    double? fraisTotal,
    String? imageUrl,
  }) {
    return Formation(
      id: id ?? this.id,
      titre: titre ?? this.titre,
      description: description ?? this.description,
      formateurId: formateurId ?? this.formateurId,
      formateurNom: formateurNom ?? this.formateurNom,
      nombreSessions: nombreSessions ?? this.nombreSessions,
      niveau: niveau ?? this.niveau,
      dateCreation: dateCreation ?? this.dateCreation,
      dateDebut: dateDebut ?? this.dateDebut,
      dateFin: dateFin ?? this.dateFin,
      centreId: centreId ?? this.centreId,
      prerequisId: clearPrerequisId ? null : (prerequisId ?? this.prerequisId),
      fraisTotal: fraisTotal ?? this.fraisTotal,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
