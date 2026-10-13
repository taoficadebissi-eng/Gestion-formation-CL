class ConversationAdminModel {
  final String id;
  final String centreId;
  final List<String> participants;
  final String? dernierMessage;
  final DateTime dateMaj;

  ConversationAdminModel({
    required this.id,
    required this.centreId,
    required this.participants,
    required this.dateMaj,
    this.dernierMessage,
  });

  factory ConversationAdminModel.fromJson(Map<String, dynamic> json) =>
      ConversationAdminModel(
        id: json['id'] ?? '',
        centreId: json['centre_id'] ?? '',
        participants: List<String>.from(json['participants'] ?? []),
        dernierMessage: json['dernier_message'],
        dateMaj: DateTime.parse(json['date_maj']),
      );

  Map<String, dynamic> toJson() => {
    'centre_id': centreId,
    'participants': participants,
    'dernier_message': dernierMessage,
    'date_maj': dateMaj.toIso8601String(),
  };
}

class MessageAdminModel {
  final String id;
  final String conversationId;
  final String auteurId;
  final String texte;
  final DateTime dateEnvoi;

  MessageAdminModel({
    required this.id,
    required this.conversationId,
    required this.auteurId,
    required this.texte,
    required this.dateEnvoi,
  });

  factory MessageAdminModel.fromJson(Map<String, dynamic> json) =>
      MessageAdminModel(
        id: json['id'] ?? '',
        conversationId: json['conversation_id'] ?? '',
        auteurId: json['auteur_id'] ?? '',
        texte: json['texte'] ?? '',
        dateEnvoi: DateTime.parse(json['date_envoi']),
      );

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationId,
    'auteur_id': auteurId,
    'texte': texte,
    'date_envoi': dateEnvoi.toIso8601String(),
  };
}
