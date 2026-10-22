// Pruebas de la semilla reproducible y de los contadores de simulación.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/metricas.dart';
import 'package:esport_agent/logica/motor_juego.dart';

Future<MotorJuego> _partida(int semilla) async {
  final motor = MotorJuego(semilla: semilla);
  await motor.nuevaPartida(nombre: 'Prueba', pais: 'Chile');
  return motor;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('la misma semilla produce el mismo estado inicial', () async {
    final a = await _partida(20251019);
    final b = await _partida(20251019);

    expect(
      jsonEncode(a.estado!.toJson()),
      equals(jsonEncode(b.estado!.toJson())),
    );
  });

  test('la misma semilla produce el mismo estado tras 12 semanas', () async {
    final a = await _partida(20251019);
    final b = await _partida(20251019);

    await a.avanzarSemanas(12);
    await b.avanzarSemanas(12);

    expect(a.semana, b.semana);
    expect(a.temporada, b.temporada);
    expect(a.agente.dinero, b.agente.dinero);
    expect(
      jsonEncode(a.estado!.toJson()),
      equals(jsonEncode(b.estado!.toJson())),
    );
  });

  test('semillas distintas producen estados distintos', () async {
    final a = await _partida(20251019);
    final b = await _partida(20251020);

    expect(
      jsonEncode(a.estado!.toJson()),
      isNot(equals(jsonEncode(b.estado!.toJson()))),
    );
  });

  test('las métricas se reinician al cambiar de temporada y de ventana', () {
    final metricas = MetricasSimulacion()
      ..fichajesIA = 5
      ..ofertasIA = 3
      ..eventosGenerados = 9
      ..eventosConDecision = 4
      ..fichajesVentana = 2
      ..ofertasVentana = 1;

    metricas.reiniciarVentana();
    expect(metricas.fichajesVentana, 0);
    expect(metricas.ofertasVentana, 0);
    expect(metricas.fichajesIA, 5);

    metricas.asegurarTemporada(2);
    expect(metricas.temporada, 2);
    expect(metricas.fichajesIA, 0);
    expect(metricas.ofertasIA, 0);
    expect(metricas.eventosGenerados, 0);
    expect(metricas.eventosConDecision, 0);
  });

  test('las métricas no forman parte del JSON guardado', () async {
    final motor = await _partida(20251019);
    final mapa =
        jsonDecode(jsonEncode(motor.estado!.toJson())) as Map<String, dynamic>;

    expect(mapa.containsKey('metricas'), isFalse);
    expect(mapa.containsKey('fichajesIA'), isFalse);
    expect(mapa.containsKey('eventosGenerados'), isFalse);
  });
}
