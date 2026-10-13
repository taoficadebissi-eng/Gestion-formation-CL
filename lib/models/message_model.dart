class MessageModel {
  final String id;
  final String formationId;
  final String auteurId;
  final String texte;
  final DateTime dateEnvoi;

  MessageModel({
    required this.id,
    required this.formationId,
    required this.auteurId,
    required this.texte,
    required this.dateEnvoi,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
    id: json['id'] ?? '',
    formationId: json['formation_id'] ?? '',
    auteurId: json['auteur_id'] ?? '',
    texte: json['texte'] ?? '',
    dateEnvoi: DateTime.parse(json['date_envoi']),
  );

  Map<String, dynamic> toJson() => {
    'formation_id': formationId,
    'auteur_id': auteurId,
    'texte': texte,
    'date_envoi': dateEnvoi.toIso8601String(),
  };
}
