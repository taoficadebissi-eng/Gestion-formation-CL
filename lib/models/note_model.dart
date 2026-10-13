class NoteModel {
  final String id;
  final String formationId;
  final String nomFichier;

  /// Lien https vers le document (hébergé hors de l'application).
  final String url;
  final String uploadePar;
  final DateTime dateAjout;

  NoteModel({
    required this.id,
    required this.formationId,
    required this.nomFichier,
    required this.url,
    required this.uploadePar,
    required this.dateAjout,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) => NoteModel(
    id: json['id'] ?? '',
    formationId: json['formation_id'] ?? '',
    nomFichier: json['nom_fichier'] ?? '',
    url: json['url'] ?? '',
    uploadePar: json['uploade_par'] ?? '',
    dateAjout: DateTime.parse(json['date_ajout']),
  );

  Map<String, dynamic> toJson() => {
    'formation_id': formationId,
    'nom_fichier': nomFichier,
    'url': url,
    'uploade_par': uploadePar,
    'date_ajout': dateAjout.toIso8601String(),
  };
}
