// Pruebas de la previa extraída a la lógica (sección 5) y del historial
// orientado al equipo local real (M3).
import 'package:flutter_test/flutter_test.dart';

import 'package:esport_agent/logica/previa_partido.dart';
import 'package:esport_agent/modelos/competicion.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';
import 'package:esport_agent/modelos/partido.dart';

Equipo _equipo(String id) => Equipo(
  id: id,
  nombre: id.toUpperCase(),
  juego: Juego.lol,
  region: 'Test',
  prestigio: 70,
  presupuesto: 1000000,
  colorPrincipal: 0xFF000000,
  escudo: '',
);

Jugador _jugador(String id, String equipoId, String rol) => Jugador(
  id: id,
  nick: id,
  nombreReal: id,
  pais: 'Test',
  edad: 22,
  juego: Juego.lol,
  rol: rol,
  habilidad: 80,
  potencial: 90,
  equipoId: equipoId,
  salarioAnual: 100000,
  semanasContrato: 20,
);

void main() {
  test('el historial se orienta a los equipos de la previa', () {
    final local = _equipo('a');
    final visitante = _equipo('b');
    final competicion = Competicion(
      juego: Juego.lol,
      region: 'Test',
      division: 1,
      liga: 'Liga Test',
      equipoIds: ['a', 'b'],
      resultadosSplit1: [
        ResultadoSerie(
          fecha: 1,
          etapa: 'Liga Split 1',
          // El visitante de la previa fue local en ese partido y ganó 3–1.
          localId: 'b',
          visitanteId: 'a',
          mapasLocal: 3,
          mapasVisitante: 1,
          ganadorId: 'b',
        ),
      ],
    );

    final previa = construirPreviaPartido(
      competicion: competicion,
      local: local,
      visitante: visitante,
      jugadores: const [],
    );

    expect(previa.historial, hasLength(1));
    // Se muestra "a 1–3 b", no "a 3–1 b".
    expect(previa.historial.single.golesLocal, 1);
    expect(previa.historial.single.golesVisitante, 3);
  });

  test('elige el duelo del mismo rol con más habilidad', () {
    final local = _equipo('a');
    final visitante = _equipo('b');
    final jugadores = [
      _jugador('a_top', 'a', 'Top'),
      _jugador('b_top', 'b', 'Top'),
      _jugador('a_mid', 'a', 'Mid'),
      _jugador('b_mid', 'b', 'Mid'),
    ];
    jugadores.firstWhere((j) => j.id == 'a_mid').habilidad = 99;
    jugadores.firstWhere((j) => j.id == 'b_mid').habilidad = 99;
    final competicion = Competicion(
      juego: Juego.lol,
      region: 'Test',
      division: 1,
      liga: 'Liga Test',
      equipoIds: ['a', 'b'],
    );

    final previa = construirPreviaPartido(
      competicion: competicion,
      local: local,
      visitante: visitante,
      jugadores: jugadores,
    );

    expect(previa.dueloClave, isNotNull);
    expect(previa.dueloClave!.rol, 'Mid');
  });
}
