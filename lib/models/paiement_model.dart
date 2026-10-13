class PaiementModel {
  final String id;
  final String inscriptionId;
  final double montant;
  final DateTime date;
  final String methode;
  final String reference;

  PaiementModel({
    required this.id,
    required this.inscriptionId,
    required this.montant,
    required this.date,
    required this.methode,
    required this.reference,
  });

  factory PaiementModel.fromJson(Map<String, dynamic> json) => PaiementModel(
    id: json['id'] ?? '',
    inscriptionId: json['inscription_id'] ?? '',
    montant: (json['montant'] as num?)?.toDouble() ?? 0,
    date: DateTime.parse(json['date']),
    methode: json['methode'] ?? '',
    reference: json['reference'] ?? '',
  );
}
