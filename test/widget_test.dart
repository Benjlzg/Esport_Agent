// Prueba básica: la app abre y muestra la pantalla de inicio.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/main.dart';

void main() {
  testWidgets('La pantalla de inicio muestra el logo', (tester) async {
    // Simulo que no hay partida guardada.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AppEsportsAgent());
    await tester.pumpAndSettle();

    expect(find.text('ESPORTS'), findsOneWidget);
    expect(find.text('AGENT'), findsOneWidget);
    expect(find.text('Nueva partida'), findsOneWidget);
  });
}
