// Prueba rápida de la métrica de dominio por liga (corrección 2.5 B3).
import 'package:flutter_test/flutter_test.dart';

import 'package:esport_agent/modelos/agente.dart';
import 'package:esport_agent/modelos/competicion.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/historial.dart';
import 'package:esport_agent/modelos/juego.dart';

import 'apoyo/entorno_simulacion.dart';

Equipo _equipo(String id, {required int division, required String liga}) =>
    Equipo(
      id: id,
      nombre: id.toUpperCase(),
      juego: Juego.lol,
      region: 'Test',
      prestigio: 60,
      presupuesto: 1000000,
      colorPrincipal: 0xFF000000,
      escudo: 'x.png',
      division: division,
      liga: liga,
    );

RegistroCampeon _titulo(int temporada, String equipo, String liga) =>
    RegistroCampeon(
      temporada: temporada,
      juego: Juego.lol,
      descripcion: '$liga (Split 1)',
      tipo: TipoCampeon.liga,
      ganadorId: equipo,
    );

void main() {
  test('cuenta temporadas distintas y solo ligas de 1ª División', () {
    final estado = EstadoPartida(
      agente: Agente(nombre: 'Test', pais: 'Test'),
      jugadores: [],
      equipos: [
        _equipo('a', division: 1, liga: 'Liga Test'),
        _equipo('b', division: 1, liga: 'Liga Test'),
        _equipo('c', division: 2, liga: 'Liga Test - Segunda'),
      ],
      noticias: [],
      competiciones: [
        Competicion(
          juego: Juego.lol,
          region: 'Test',
          division: 1,
          liga: 'Liga Test',
          equipoIds: ['a', 'b'],
        ),
        Competicion(
          juego: Juego.lol,
          region: 'Test',
          division: 2,
          liga: 'Liga Test - Segunda',
          equipoIds: ['c'],
        ),
      ],
      palmares: [
        // A gana los dos splits de la T1: cuenta como 1 temporada.
        _titulo(1, 'a', 'Liga Test'),
        _titulo(1, 'a', 'Liga Test'),
        // A gana la T2 y B la T3.
        _titulo(2, 'a', 'Liga Test'),
        _titulo(3, 'b', 'Liga Test'),
        // Título de 2ª División: no debe mezclarse con la 1ª.
        _titulo(1, 'c', 'Liga Test - Segunda'),
      ],
    );

    final dominio = dominioPorLiga(estado);

    expect(dominio, hasLength(1));
    expect(dominio.first.liga, contains('Liga Test'));
    expect(dominio.first.equipoId, 'a');
    expect(dominio.first.temporadasGanadas, 2);
    expect(dominio.first.titulosSplit, 3);
  });
}
