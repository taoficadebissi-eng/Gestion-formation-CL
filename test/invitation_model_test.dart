import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion/models/invitation_model.dart';

void main() {
  group('InvitationModel.depuisMap : lecture tolérante', () {
    test('nouveau format : id = code, date ISO', () {
      final c = InvitationModel.depuisMap('INV-AAAAA-BBBBB', {
        'token': 'INV-AAAAA-BBBBB',
        'utilise': false,
        'admin_id': null,
        'date_creation': '2026-10-13T20:00:00.000',
      });
      expect(c.valide, isTrue);
      expect(c.disponible, isTrue);
      expect(c.date, DateTime(2026, 10, 13, 20));
    });

    test(
      'ancien format (champs camelCase, Timestamp, id aléatoire) ne plante pas',
      () {
        final c = InvitationModel.depuisMap('x7Hq2LmZ', {
          'token': 'INV-123456-7890',
          'utilise': false,
          'adminId': null,
          'dateCreation': Timestamp.fromDate(DateTime(2026, 7, 1)),
        });
        expect(c.token, 'INV-123456-7890');
        expect(c.valide, isFalse, reason: 'inutilisable : id != code');
        expect(c.disponible, isFalse);
        expect(c.date, DateTime(2026, 7, 1));
      },
    );

    test('document incomplet ou aux types inattendus ne plante pas', () {
      final vide = InvitationModel.depuisMap('abc', {});
      expect(vide.token, 'abc');
      expect(vide.utilise, isFalse);
      expect(vide.date, isNull);

      final bizarre = InvitationModel.depuisMap('abc', {
        'token': 42,
        'utilise': 'oui',
        'date_creation': 123,
      });
      expect(bizarre.token, 'abc');
      expect(bizarre.utilise, isFalse);
      expect(bizarre.date, isNull);
    });

    test('un code utilisé n\'est plus disponible', () {
      final c = InvitationModel.depuisMap('INV-A', {
        'token': 'INV-A',
        'utilise': true,
      });
      expect(c.valide, isTrue);
      expect(c.disponible, isFalse);
    });
  });
}
