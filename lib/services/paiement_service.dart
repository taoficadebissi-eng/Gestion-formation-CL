import '../core/supabase/supabase_config.dart';
import '../models/paiement_model.dart';

class PaiementService {
  final _db = SupabaseConfig.client;

  Stream<List<PaiementModel>> ecouterPaiements(String inscriptionId) {
    return _db
        .from('paiements')
        .stream(primaryKey: ['id'])
        .eq('inscription_id', inscriptionId)
        .order('date', ascending: false)
        .map((rows) => rows.map(PaiementModel.fromJson).toList());
  }
}
