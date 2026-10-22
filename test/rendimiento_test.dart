// Prueba de rendimiento del mercado (corrección I9).
//
// Comprueba que revisar una ventana con ~320 equipos y ~2.800 jugadores no
// vuelve a ser el bucle O(equipos × roles × jugadores) de antes.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:esport_agent/logica/indices_mundo.dart';
import 'package:esport_agent/logica/mercado.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';
import 'package:esport_agent/modelos/agente.dart';

Equipo _equipo(String id) => Equipo(
  id: id,
  nombre: 'Equipo $id',
  juego: Juego.lol,
  region: 'Test',
  prestigio: 60,
  presupuesto: 1000000,
  colorPrincipal: 0xFF000000,
  escudo: 'x.png',
);

Jugador _jugador(
  String id, {
  required String? equipoId,
  required String rol,
  int habilidad = 50,
}) => Jugador(
  id: id,
  nick: 'Nick $id',
  nombreReal: 'Jugador $id',
  pais: 'Test',
  edad: 23,
  juego: Juego.lol,
  rol: rol,
  habilidad: habilidad,
  potencial: 90,
  equipoId: equipoId,
  region: 'Test',
  salarioAnual: 50000,
  semanasContrato: 100,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('una ventana con 320 equipos y 2.800 jugadores es rápida', () {
    const cantidadEquipos = 320;
    const cantidadJugadores = 2800;
    final equipos = <Equipo>[];
    final jugadores = <Jugador>[];
    var siguiente = 0;

    for (var e = 0; e < cantidadEquipos; e++) {
      final equipo = _equipo('t${e.toString().padLeft(3, '0')}');
      equipos.add(equipo);
      for (final rol in Juego.lol.roles) {
        jugadores.add(
          _jugador(
            'p${(siguiente++).toString().padLeft(4, '0')}',
            equipoId: equipo.id,
            rol: rol,
          ),
        );
      }
    }
    while (jugadores.length < cantidadJugadores) {
      jugadores.add(
        _jugador(
          'p${(siguiente++).toString().padLeft(4, '0')}',
          equipoId: null,
          rol: Juego.lol.roles[siguiente % Juego.lol.roles.length],
          habilidad: 55,
        ),
      );
    }

    final estado = EstadoPartida(
      agente: Agente(nombre: 'Test', pais: 'Test', dinero: 0),
      jugadores: jugadores,
      equipos: equipos,
      noticias: [],
      semana: 5,
    );

    final cronometro = Stopwatch()..start();
    final resultado = procesarMercadoIA(
      estado: estado,
      indiceEquipos: {for (final e in equipos) e.id: e},
      indiceJugadores: {for (final j in jugadores) j.id: j},
      rnd: Random(20251019),
      nuevoIdJugador: () => 'n${siguiente++}',
    );
    cronometro.stop();

    // Umbral amplio para no fallar en máquinas lentas, pero muy por debajo de
    // lo que tardaría recorriendo 320 × 5 × 2.800 comparaciones por rol.
    expect(
      cronometro.elapsedMilliseconds,
      lessThan(3000),
      reason:
          'La ventana tardó ${cronometro.elapsedMilliseconds} ms '
          '(fichajes: ${resultado.fichajesCerrados}).',
    );
  });

  test('los índices de plantilla y representados siguen los traspasos', () {
    final equipoA = _equipo('a');
    final equipoB = _equipo('b');
    final jugador = _jugador('p1', equipoId: 'a', rol: Juego.lol.roles.first)
      ..representadoPorMi = true;
    final estado = EstadoPartida(
      agente: Agente(nombre: 'Test', pais: 'Test'),
      jugadores: [jugador],
      equipos: [equipoA, equipoB],
      noticias: [],
    );
    final indices = IndicesMundo()..reconstruir(estado);

    expect(indices.titularDe('a', jugador.rol), same(jugador));
    expect(indices.representadosPorEquipo['a'], [jugador]);

    // Cambia de equipo y de rol: los índices viejos deben quedar limpios.
    jugador.equipoId = 'b';
    jugador.rol = Juego.lol.roles[1];
    indices.actualizar(jugador);

    expect(indices.titularDe('a', Juego.lol.roles.first), isNull);
    expect(indices.titularDe('b', Juego.lol.roles[1]), same(jugador));
    expect(indices.representadosPorEquipo['a'], isNull);
    expect(indices.representadosPorEquipo['b'], [jugador]);
    expect(indices.plantillaDe('a'), isEmpty);
    expect(indices.plantillaDe('b'), [jugador]);
  });
}
