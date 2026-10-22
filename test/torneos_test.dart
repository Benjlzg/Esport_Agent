// Pruebas de la lógica de torneos: reparto de byes del bracket y reparto
// de premios de un torneo de eliminación directa.
import 'package:flutter_test/flutter_test.dart';

import 'package:esport_agent/logica/torneos.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/partido.dart';
import 'package:esport_agent/modelos/torneo.dart';

Equipo _equipo(String id, {int presupuesto = 0}) => Equipo(
  id: id,
  nombre: id.toUpperCase(),
  juego: Juego.lol,
  region: 'Test',
  prestigio: 50,
  presupuesto: presupuesto,
  colorPrincipal: 0xFF000000,
  escudo: 'x.png',
);

ResultadoSerie _serie(
  String local,
  String visitante, {
  required String etapa,
  int mapasLocal = 3,
  int mapasVisitante = 1,
}) => ResultadoSerie(
  fecha: 0,
  etapa: etapa,
  localId: local,
  visitanteId: visitante,
  mapasLocal: mapasLocal,
  mapasVisitante: mapasVisitante,
  ganadorId: local,
);

void main() {
  group('construirBracket', () {
    test('con 7 equipos da 1 bye a los de mayor prestigio', () {
      final cruces = construirBracket([
        't1',
        't2',
        't3',
        't4',
        't5',
        't6',
        't7',
      ]);
      expect(cruces.length, 4);
      expect(cruces.first, ('t1', null));
      expect(cruces.contains(('t2', 't7')), isTrue);
      expect(cruces.contains(('t3', 't6')), isTrue);
      expect(cruces.contains(('t4', 't5')), isTrue);
    });

    test('con 4 equipos todos cruzan sin byes', () {
      final cruces = construirBracket(['t1', 't2', 't3', 't4']);
      expect(cruces.length, 2);
      expect(cruces.any((c) => c.$2 == null), isFalse);
    });
  });

  group('reparto de premios', () {
    final torneo = Torneo(
      id: 'mitad_lol_1',
      tipo: TipoTorneo.mitad,
      juego: Juego.lol,
      temporada: 1,
      nombre: 'Torneo de Mitad de Temporada',
      participantes: ['a', 'b', 'c', 'd'],
      rondas: [
        [
          _serie(
            'a',
            'b',
            etapa: 'Semifinal',
            mapasLocal: 3,
            mapasVisitante: 1,
          ),
          _serie(
            'c',
            'd',
            etapa: 'Semifinal',
            mapasLocal: 3,
            mapasVisitante: 2,
          ),
        ],
        [_serie('a', 'c', etapa: 'Final', mapasLocal: 3, mapasVisitante: 2)],
      ],
    );

    test('el campeón se lleva el 50% del bote', () {
      final distribucion = distribucionPremios(torneo);
      expect(distribucion['a'], 250000); // campeón: 50% de 500.000
      expect(distribucion['c'], 125000); // finalista: 25%
      expect(distribucion['b'], 62500); // semifinalista: 12,5%
      expect(distribucion['d'], 62500);
    });

    test('repartirPremios suma el dinero al presupuesto', () {
      final equipos = {
        for (final id in ['a', 'b', 'c', 'd']) id: _equipo(id),
      };
      repartirPremios(torneo, equipos);
      expect(equipos['a']!.presupuesto, 250000);
      expect(equipos['b']!.presupuesto, 62500);
    });

    test('el campeón es el ganador de la final', () {
      expect(torneo.campeonId, 'a');
      expect(torneo.subcampeonId, 'c');
    });
  });
}
