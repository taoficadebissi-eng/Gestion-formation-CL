import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

/// État de la dernière veille automatique (document `veille_etat/courant`,
/// tenu à jour par le programme de veille).
class EtatVeille {
  final String statut; // en_cours | termine | erreur
  final String declencheur; // bouton | planifie | manuel
  final DateTime? debut;
  final DateTime? fin;
  final String message;

  const EtatVeille({
    required this.statut,
    required this.declencheur,
    required this.debut,
    required this.fin,
    required this.message,
  });

  factory EtatVeille.fromMap(Map<String, dynamic> d) => EtatVeille(
    statut: (d['statut'] as String?) ?? '',
    declencheur: (d['declencheur'] as String?) ?? '',
    debut: _date(d['debut']),
    fin: _date(d['fin']),
    message: (d['message'] as String?) ?? '',
  );

  bool get enCours => statut == 'en_cours';
  bool get enErreur => statut == 'erreur';
}

/// Demande de lancement faite depuis l'application (`veille_demandes`).
class DemandeVeille {
  final String id;
  final String statut; // en_attente | en_cours | termine | erreur
  final DateTime? dateDemande;
  final String message;

  const DemandeVeille({
    required this.id,
    required this.statut,
    required this.dateDemande,
    required this.message,
  });

  factory DemandeVeille.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return DemandeVeille(
      id: doc.id,
      statut: (d['statut'] as String?) ?? '',
      dateDemande: _date(d['dateDemande']),
      message: (d['message'] as String?) ?? '',
    );
  }

  bool get active => statut == 'en_attente' || statut == 'en_cours';
}
