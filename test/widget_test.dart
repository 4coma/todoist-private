// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_app/main.dart';

void main() {
  testWidgets('Todo app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TodoApp());

    // Verify that the app title is displayed.
    expect(find.text('Ma Liste de Tâches'), findsOneWidget);
    
    // Verify that the empty state message is displayed.
    expect(find.text('Aucune tâche pour le moment'), findsOneWidget);
    expect(find.text('Ajoutez votre première tâche !'), findsOneWidget);

    // Verify that the input field is present.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Ajouter une nouvelle tâche...'), findsOneWidget);

    // Verify that the add button is present.
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
