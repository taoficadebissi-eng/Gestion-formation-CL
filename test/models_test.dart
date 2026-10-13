import 'package:flutter_test/flutter_test.dart';
import 'package:gestion/models/formation_model.dart';
import 'package:gestion/models/inscription_model.dart';
import 'package:gestion/models/user_model.dart';
import 'package:gestion/services/inscription_service.dart';
import 'package:gestion/services/presence_service.dart';

void main() {
  group('UserModel', () {
    test('un admin sans centre garde centreId vide et stocke null', () {
      final user = UserModel.fromJson({
        'id': 'u1',
        'nom': 'A',
        'prenom': 'B',
        'email': 'a@b.c',
        'role': 'admin',
        'centre_id': null,
        'is_first_login': false,
      });
      expect(user.role, UserRole.admin);
      expect(user.centreId, '');
      expect(user.toJson()['centre_id'], isNull);
    });

    test('role inconnu => apprenant (valeur la moins privilegiee)', () {
      final user = UserModel.fromJson({
        'id': 'u1',
        'role': 'root',
        'date': null,
      });
      expect(user.role, UserRole.apprenant);
    });

    test('premier login force le changement de mot de passe', () {
      final user = UserModel.fromJson({'id': 'u', 'is_first_login': true});
      expect(user.mustChangePassword, isTrue);
    });
  });

  group('InscriptionModel', () {
    test('toJson ne contient jamais les champs de paiement', () {
      final inscription = InscriptionModel(
        id: 'a_f',
        apprenantId: 'a',
        apprenantNom: 'A',
        formationId: 'f',
        centreId: 'c',
        dateInscription: DateTime(2026, 1, 1),
        statut: StatutInscription.confirmee,
        montantPaye: 50,
        montantRestant: 50,
        statutPaiement: StatutPaiement.bloque,
      );
      final json = inscription.toJson();
      expect(json.containsKey('montant_paye'), isFalse);
      expect(json.containsKey('montant_restant'), isFalse);
      expect(json.containsKey('statut_paiement'), isFalse);
    });

    test('StatutPaiement aller-retour JSON', () {
      for (final statut in StatutPaiement.values) {
        expect(StatutPaiementJson.fromJson(statut.toJson()), statut);
      }
      expect(StatutPaiementJson.fromJson('inconnu'), StatutPaiement.aJour);
    });

    test('fromJson lit les montants entiers ou decimaux', () {
      final inscription = InscriptionModel.fromJson({
        'id': 'a_f',
        'date_inscription': '2026-01-01T00:00:00.000',
        'statut': 'confirmee',
        'statut_paiement': 'en_retard',
        'montant_paye': 10,
        'montant_restant': 90.5,
      });
      expect(inscription.montantPaye, 10.0);
      expect(inscription.montantRestant, 90.5);
      expect(inscription.statutPaiement, StatutPaiement.enRetard);
    });
  });

  group('Formation', () {
    test('un prerequis vide est stocke null', () {
      final formation = Formation.fromJson({
        'id': 'f',
        'date_creation': '2026-01-01T00:00:00.000',
      });
      expect(formation.copyWith(prerequisId: '').toJson()['prerequis_id'], isNull);
      expect(formation.toJson()['formateur_id'], isNull);
    });

    test('clearPrerequisId efface le prerequis', () {
      final formation = Formation.fromJson({
        'id': 'f',
        'date_creation': '2026-01-01T00:00:00.000',
        'prerequis_id': 'p',
      });
      expect(formation.prerequisId, 'p');
      expect(formation.copyWith(clearPrerequisId: true).prerequisId, isNull);
    });
  });

  group('ids deterministes (alignes sur les regles Firestore)', () {
    test('inscription = apprenant_formation', () {
      expect(InscriptionService.idInscription('a1', 'f1'), 'a1_f1');
    });

    test('presence = session_apprenant', () {
      expect(PresenceService.idPresence('s1', 'a1'), 's1_a1');
    });
  });
}
