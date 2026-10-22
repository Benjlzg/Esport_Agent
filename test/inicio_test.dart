// Pruebas de la pantalla de inicio (I13/M13): empezar una partida nueva ya
// no borra la anterior hasta que se confirma la creación, y "Continuar" se
// actualiza al volver.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/pantallas/pantalla_inicio.dart';
import 'package:esport_agent/servicios/guardado.dart';

const int _semilla = 20251019;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    (rootBundle as CachingAssetBundle).clear();
  });

  testWidgets('volver de "Crear agente" conserva la partida anterior', (
    tester,
  ) async {
    // Crea y guarda una partida.
    final anterior = MotorJuego(semilla: _semilla);
    await anterior.nuevaPartida(nombre: 'Anterior', pais: 'Chile');
    expect(await existePartida(), isTrue);

    // Un motor nuevo simula abrir la app de cero.
    final motor = MotorJuego(semilla: _semilla);
    await tester.pumpWidget(MaterialApp(home: PantallaInicio(motor: motor)));
    await tester.pumpAndSettle();
    expect(find.text('Continuar'), findsOneWidget);

    await tester.tap(find.text('Nueva partida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empezar nueva'));
    await tester.pumpAndSettle();
    expect(find.text('Crear agente'), findsOneWidget);

    // Se arrepiente y vuelve atrás: la partida guardada debe seguir ahí.
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(await existePartida(), isTrue);
    expect(find.text('Continuar'), findsOneWidget);

    final cargada = MotorJuego(semilla: _semilla);
    expect(await cargada.cargar(), ResultadoCarga.ok);
    expect(cargada.agente.nombre, 'Anterior');
  });
}
