// Pruebas de borrado de la auditoría (C2): al borrar la partida, las
// pantallas que siguen escuchando al motor no deben lanzar una excepción y
// deben volver al inicio.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/pantallas/pantalla_ajustes.dart';
import 'package:esport_agent/pantallas/pantalla_principal.dart';

const int _semilla = 20251019;

Future<MotorJuego> _partidaNueva() async {
  final motor = MotorJuego(semilla: _semilla);
  await motor.nuevaPartida(nombre: 'Agente Prueba', pais: 'Chile');
  return motor;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Evita que el bundle de assets quede cacheado entre pruebas.
    (rootBundle as CachingAssetBundle).clear();
  });

  testWidgets('borrar desde Ajustes no lanza y vuelve al inicio', (
    tester,
  ) async {
    final motor = await _partidaNueva();
    await tester.pumpWidget(MaterialApp(home: PantallaAjustes(motor: motor)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Borrar partida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, borrar todo'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(motor.hayPartida, isFalse);
    expect(find.text('ESPORTS'), findsOneWidget);
    expect(find.text('Nueva partida'), findsOneWidget);
  });

  testWidgets('empezar de nuevo tras la bancarrota no lanza', (tester) async {
    final motor = await _partidaNueva();
    motor.estado!.finDelJuego = true;

    await tester.pumpWidget(MaterialApp(home: PantallaPrincipal(motor: motor)));
    await tester.pumpAndSettle();
    expect(find.text('Fin del juego'), findsOneWidget);

    await tester.tap(find.text('Empezar de nuevo'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(motor.hayPartida, isFalse);
    expect(find.text('ESPORTS'), findsOneWidget);
  });
}
