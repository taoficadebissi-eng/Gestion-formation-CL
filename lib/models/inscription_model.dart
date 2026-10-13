enum StatutInscription { enAttente, confirmee, annulee }

enum StatutPaiement { aJour, enRetard, bloque }

extension StatutPaiementJson on StatutPaiement {
  static StatutPaiement fromJson(String? value) {
    switch (value) {
      case 'en_retard':
        return StatutPaiement.enRetard;
      case 'bloque':
        return StatutPaiement.bloque;
      case 'a_jour':
      default:
        return StatutPaiement.aJour;
    }
  }

  String toJson() {
    switch (this) {
      case StatutPaiement.enRetard:
        return 'en_retard';
      case StatutPaiement.bloque:
        return 'bloque';
      case StatutPaiement.aJour:
        return 'a_jour';
    }
  }
}

class InscriptionModel {
  final String id;
  final String apprenantId;
  final String apprenantNom;
  final String formationId;
  final String centreId;
  final DateTime dateInscription;
  final StatutInscription statut;
  final StatutPaiement statutPaiement;
  final double montantPaye;
  final double montantRestant;

  InscriptionModel({
    required this.id,
    required this.apprenantId,
    required this.apprenantNom,
    required this.formationId,
    required this.centreId,
    required this.dateInscription,
    required this.statut,
    this.statutPaiement = StatutPaiement.aJour,
    this.montantPaye = 0,
    this.montantRestant = 0,
  });

  factory InscriptionModel.fromJson(Map<String, dynamic> json) =>
      InscriptionModel(
        id: json['id'] ?? '',
        apprenantId: json['apprenant_id'] ?? '',
        apprenantNom: json['apprenant_nom'] ?? '',
        formationId: json['formation_id'] ?? '',
        centreId: json['centre_id'] ?? '',
        dateInscription: DateTime.parse(json['date_inscription']),
        statut: StatutInscription.values.firstWhere(
          (e) => e.name == json['statut'],
          orElse: () => StatutInscription.enAttente,
        ),
        statutPaiement: StatutPaiementJson.fromJson(json['statut_paiement']),
        montantPaye: (json['montant_paye'] as num?)?.toDouble() ?? 0,
        montantRestant: (json['montant_restant'] as num?)?.toDouble() ?? 0,
      );

  // Ne contient PAS statut_paiement/montant_paye/montant_restant : ces
  // champs sont protégés par un trigger côté base (voir
  // 0002_phase2.sql, prevent_direct_payment_change) et ne doivent jamais
  // être écrits via ce toJson() générique. Seul InscriptionService expose
  // des méthodes dédiées et volontairement étroites pour les modifier
  // (enregistrerPaiement via l'Edge Function, togglerBlocage pour l'admin).
  Map<String, dynamic> toJson() => {
    'apprenant_id': apprenantId,
    'apprenant_nom': apprenantNom,
    'formation_id': formationId,
    'centre_id': centreId,
    'date_inscription': dateInscription.toIso8601String(),
    'statut': statut.name,
  };

  // ✅ MÉTHODE OBLIGATOIRE POUR LA SÉCURITÉ MULTI-TENANT
  InscriptionModel copyWith({
    String? id,
    String? apprenantId,
    String? apprenantNom,
    String? formationId,
    String? centreId,
    DateTime? dateInscription,
    StatutInscription? statut,
    StatutPaiement? statutPaiement,
    double? montantPaye,
    double? montantRestant,
  }) {
    return InscriptionModel(
      id: id ?? this.id,
      apprenantId: apprenantId ?? this.apprenantId,
      apprenantNom: apprenantNom ?? this.apprenantNom,
      formationId: formationId ?? this.formationId,
      centreId: centreId ?? this.centreId,
      dateInscription: dateInscription ?? this.dateInscription,
      statut: statut ?? this.statut,
      statutPaiement: statutPaiement ?? this.statutPaiement,
      montantPaye: montantPaye ?? this.montantPaye,
      montantRestant: montantRestant ?? this.montantRestant,
    );
  }
}
