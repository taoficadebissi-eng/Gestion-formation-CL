import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion/main.dart';

void main() {
  testWidgets('Gestion Formation App', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Vérifier que l'app se lance sans crash
    await tester.pumpAndSettle();

    // Vérifier qu'il y a au moins un widget Material
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
