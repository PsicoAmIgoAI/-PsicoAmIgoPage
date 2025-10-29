import 'package:flutter_test/flutter_test.dart';
import 'package:psicoamigoweb/main.dart'; // Asegúrate que la ruta sea correcta
import 'package:flutter/material.dart';

void main() {
  testWidgets('Verifica que carga pantalla principal PsicoAmIgo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PsicoAmIgoApp()));

    // Esperamos encontrar el título "PsicoAmIgo"
    expect(find.text('PsicoAmIgoWeb'), findsOneWidget);

    // Verificamos que el TabBar está presente
    expect(find.byType(TabBar), findsOneWidget);

    // Verificamos que no estamos en modo carga
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
