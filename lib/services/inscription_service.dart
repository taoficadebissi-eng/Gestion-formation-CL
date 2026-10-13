import '../core/firebase/firestore_helpers.dart';
import '../models/formation_model.dart';
import '../models/inscription_model.dart';

class InscriptionService {
  final _col = firestore.collection('inscriptions');

  /// Une inscription par (apprenant, formation) : l'id déterministe empêche
  /// la double inscription et permet aux règles Firestore de vérifier
  /// l'inscription d'un apprenant sans requête.
  static String idInscription(String apprenantId, String formationId) =>
      '${apprenantId}_$formationId';

  Stream<List<InscriptionModel>> ecouterInscriptionsFormation(
    String formationId,
    String centreId,
  ) {
    return _col
        .where('centre_id', isEqualTo: centreId)
        .where('formation_id', isEqualTo: formationId)
        .snapshots()
        .map((s) => s.toJsonListe().map(InscriptionModel.fromJson).toList());
  }

  Stream<List<InscriptionModel>> ecouterInscriptionsApprenant(
    String apprenantId,
  ) {
    return _col
        .where('apprenant_id', isEqualTo: apprenantId)
        .snapshots()
        .map((s) => s.toJsonListe().map(InscriptionModel.fromJson).toList());
  }

  Future<bool> estInscrit(String apprenantId, String formationId) async {
    final doc = await _col.doc(idInscription(apprenantId, formationId)).get();
    return doc.exists;
  }

  Future<void> inscrire(InscriptionModel inscription) async {
    final ref = _col.doc(
      idInscription(inscription.apprenantId, inscription.formationId),
    );
    if ((await ref.get()).exists) {
      throw Exception('Vous etes deja inscrit a cette formation');
    }
    final formationDoc = await firestore
        .collection('formations')
        .doc(inscription.formationId)
        .get();
    final json = formationDoc.toJsonAvecId();
    if (json == null) throw Exception('Formation introuvable');
    final frais = Formation.fromJson(json).fraisTotal;

    // Etat de paiement initial : les règles Firestore l'imposent aux
    // non-admins (rien payé, tout le montant restant dû).
    await ref.set({
      ...inscription.toJson(),
      'statut_paiement': StatutPaiement.aJour.toJson(),
      'montant_paye': 0,
      'montant_restant': frais,
    });
  }

  Future<void> modifier(InscriptionModel inscription) async {
    await _col.doc(inscription.id).update({'statut': inscription.statut.name});
  }

  Future<void> annuler(String id) async {
    await _col.doc(id).delete();
  }

  /// Enregistre un paiement manuel : ajoute la ligne dans `paiements` et met
  /// à jour l'inscription dans une même transaction. Les règles Firestore
  /// réservent les deux écritures à l'admin propriétaire du centre et
  /// vérifient que le total payé augmente exactement du montant saisi.
  Future<void> enregistrerPaiement({
    required String inscriptionId,
    required double montant,
    String methode = 'manuel',
    String reference = '',
  }) async {
    if (montant <= 0) throw Exception('Montant invalide');
    final inscriptionRef = _col.doc(inscriptionId);

    await firestore.runTransaction((tx) async {
      final inscriptionDoc = await tx.get(inscriptionRef);
      final json = inscriptionDoc.toJsonAvecId();
      if (json == null) throw Exception('Inscription introuvable');
      final inscription = InscriptionModel.fromJson(json);

      final formationDoc = await tx.get(
        firestore.collection('formations').doc(inscription.formationId),
      );
      final formationJson = formationDoc.toJsonAvecId();
      final frais = formationJson == null
          ? 0.0
          : Formation.fromJson(formationJson).fraisTotal;

      final nouveauPaye = inscription.montantPaye + montant;
      final nouveauRestant = (frais - nouveauPaye).clamp(0, double.infinity);
      final nouveauStatut = nouveauRestant <= 0
          ? StatutPaiement.aJour
          : inscription.statutPaiement;

      tx.set(firestore.collection('paiements').doc(), {
        'inscription_id': inscriptionId,
        'montant': montant,
        'date': DateTime.now().toIso8601String(),
        'methode': methode,
        'reference': reference,
      });
      tx.update(inscriptionRef, {
        'montant_paye': nouveauPaye,
        'montant_restant': nouveauRestant,
        'statut_paiement': nouveauStatut.toJson(),
      });
    });
  }

  /// Force/lève manuellement le statut "bloqué" (action admin).
  Future<void> togglerBlocage(String inscriptionId, bool bloquer) async {
    await _col.doc(inscriptionId).update({
      'statut_paiement': (bloquer ? StatutPaiement.bloque : StatutPaiement.aJour)
          .toJson(),
    });
  }
}
