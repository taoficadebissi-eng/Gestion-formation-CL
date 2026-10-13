import '../core/supabase/supabase_config.dart';
import '../models/inscription_model.dart';

class InscriptionService {
  final _db = SupabaseConfig.client;

  // Le stream realtime de supabase_flutter n'accepte qu'un seul .eq() côté
  // serveur : on filtre sur centreId (partition de tenant, alignée avec les
  // policies RLS) puis on affine sur formationId côté client.
  Stream<List<InscriptionModel>> ecouterInscriptionsFormation(
    String formationId,
    String centreId,
  ) {
    return _db
        .from('inscriptions')
        .stream(primaryKey: ['id'])
        .eq('centre_id', centreId)
        .map(
          (rows) => rows
              .where((row) => row['formation_id'] == formationId)
              .map(InscriptionModel.fromJson)
              .toList(),
        );
  }

  // Inchangé : un apprenant lit toujours SES propres inscriptions,
  // donc la règle "apprenantId == request.auth.uid" suffit, pas besoin de centreId ici.
  Stream<List<InscriptionModel>> ecouterInscriptionsApprenant(
    String apprenantId,
  ) {
    return _db
        .from('inscriptions')
        .stream(primaryKey: ['id'])
        .eq('apprenant_id', apprenantId)
        .map((rows) => rows.map(InscriptionModel.fromJson).toList());
  }

  Future<bool> estInscrit(String apprenantId, String formationId) async {
    final rows = await _db
        .from('inscriptions')
        .select('id')
        .eq('apprenant_id', apprenantId)
        .eq('formation_id', formationId);
    return rows.isNotEmpty;
  }

  Future<void> inscrire(InscriptionModel inscription) async {
    final dejaInscrit = await estInscrit(
      inscription.apprenantId,
      inscription.formationId,
    );
    if (dejaInscrit) {
      throw Exception('Vous etes deja inscrit a cette formation');
    }
    await _db.from('inscriptions').insert(inscription.toJson());
  }

  Future<void> modifier(InscriptionModel inscription) async {
    await _db
        .from('inscriptions')
        .update(inscription.toJson())
        .eq('id', inscription.id);
  }

  Future<void> annuler(String id) async {
    await _db.from('inscriptions').delete().eq('id', id);
  }

  /// Enregistre un paiement manuel (validé par l'admin) via l'Edge Function
  /// `enregistrer-paiement`, seule habilitée à recalculer montantPaye /
  /// montantRestant / statutPaiement (voir le trigger
  /// prevent_direct_payment_change dans 0002_phase2.sql — écrire ces champs
  /// directement depuis le client est bloqué par la base, intentionnellement).
  Future<void> enregistrerPaiement({
    required String inscriptionId,
    required double montant,
    String methode = 'manuel',
    String reference = '',
  }) async {
    await _db.functions.invoke(
      'enregistrer-paiement',
      body: {
        'inscriptionId': inscriptionId,
        'montant': montant,
        'methode': methode,
        'reference': reference,
      },
    );
  }

  /// Force/leve manuellement le statut "bloque" — action admin directe,
  /// autorisée par le trigger de protection (is_owner_of_centre) sans
  /// passer par l'Edge Function.
  Future<void> togglerBlocage(String inscriptionId, bool bloquer) async {
    await _db
        .from('inscriptions')
        .update({'statut_paiement': bloquer ? 'bloque' : 'a_jour'})
        .eq('id', inscriptionId);
  }
}
