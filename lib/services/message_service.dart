import '../core/firebase/firestore_helpers.dart';
import '../models/message_model.dart';

/// Chat de groupe par formation.
class MessageService {
  final _col = firestore.collection('messages');

  Stream<List<MessageModel>> ecouterMessages(String formationId) {
    return _col.where('formation_id', isEqualTo: formationId).snapshots().map((
      s,
    ) {
      final liste = s.toJsonListe().map(MessageModel.fromJson).toList();
      liste.sort((a, b) => a.dateEnvoi.compareTo(b.dateEnvoi));
      return liste;
    });
  }

  Future<void> envoyer(MessageModel message) async {
    await _col.add(message.toJson());
  }
}
