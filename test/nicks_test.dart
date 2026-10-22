// Pruebas de la corrección 2.5: dos jugadores no pueden tener el mismo nick.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/generador_jugadores.dart';
import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';

Jugador _jugador(String id, String nick) {
  return Jugador(
    id: id,
    nick: nick,
    nombreReal: nick,
    pais: 'Test',
    edad: 20,
    juego: Juego.lol,
    rol: 'Mid',
    habilidad: 50,
    potencial: 60,
    salarioAnual: 1000,
    semanasContrato: 10,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('el mundo inicial no tiene nicks repetidos', () async {
    final motor = MotorJuego(semilla: 20251019);
    await motor.nuevaPartida(nombre: 'Prueba', pais: 'Chile');

    final nicks = motor.jugadores.map((j) => j.nick).toList();
    expect(nicks.toSet().length, nicks.length);
  });

  test('los jugadores generados no repiten nicks', () {
    final rnd = Random(7);
    final usados = <String>{};
    for (var i = 0; i < 500; i++) {
      generarJugadorLibre(rnd, id: 'p$i', nicksUsados: usados);
    }

    expect(usados.length, 500);
  });

  test('reservar un nick repetido agrega un número', () {
    final usados = <String>{};
    expect(reservarNickUnico('Drift', usados), 'Drift');
    expect(reservarNickUnico('Drift', usados), 'Drift2');
    expect(reservarNickUnico('Drift', usados), 'Drift3');
  });

  test('asegurarNicksUnicos corrige una lista con duplicados', () {
    final jugadores = [
      _jugador('p1', 'Drift'),
      _jugador('p2', 'Drift'),
      _jugador('p3', 'Drift'),
    ];

    asegurarNicksUnicos(jugadores);

    expect(jugadores.map((j) => j.nick).toList(), [
      'Drift',
      'Drift2',
      'Drift3',
    ]);
  });
}
