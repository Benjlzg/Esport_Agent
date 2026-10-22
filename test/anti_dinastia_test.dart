// Pruebas de la auditoría para el mecanismo anti-dinastía (C3):
// - Una dinastía no ficha automáticamente a un jugador representado: le hace
//   una oferta con la cláusula de salida y el jugador sigue en su club.
// - Los fichajes juveniles de 2ª División nunca se llevan a un representado,
//   solo fichan jóvenes de 21 años o menos y respetan el máximo de suplentes.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:esport_agent/logica/mercado.dart';
import 'package:esport_agent/modelos/agente.dart';
import 'package:esport_agent/modelos/competicion.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/historial.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';
import 'package:esport_agent/modelos/oferta.dart';

Jugador _jugador(
  String id, {
  String? equipoId,
  bool representadoPorMi = false,
  bool suplente = false,
  int edad = 20,
  String region = 'Test',
  int habilidad = 70,
}) => Jugador(
  id: id,
  nick: id.toUpperCase(),
  nombreReal: id,
  pais: 'Test',
  edad: edad,
  juego: Juego.lol,
  rol: 'Mid',
  habilidad: habilidad,
  potencial: habilidad + 5,
  equipoId: equipoId,
  representadoPorMi: representadoPorMi,
  suplente: suplente,
  region: region,
  salarioAnual: 100000,
  semanasContrato: 100,
);

Equipo _equipo(
  String id, {
  int prestigio = 70,
  int presupuesto = 1000000,
  int division = 1,
}) => Equipo(
  id: id,
  nombre: id.toUpperCase(),
  juego: Juego.lol,
  region: 'Test',
  prestigio: prestigio,
  presupuesto: presupuesto,
  division: division,
  colorPrincipal: 0xFF000000,
  escudo: 'x.png',
);

EstadoPartida _estado({
  required List<Jugador> jugadores,
  required List<Equipo> equipos,
  int temporada = 2,
  int semana = 1,
  List<RegistroCampeon>? palmares,
}) => EstadoPartida(
  agente: Agente(nombre: 'Test', pais: 'Test', dinero: 100000),
  jugadores: jugadores,
  equipos: equipos,
  noticias: [],
  palmares: palmares ?? [],
  temporada: temporada,
  semana: semana,
);

/// Títulos recientes de una dinastía: 6 splits en 3 temporadas.
List<RegistroCampeon> _titulosDeDinastia(String equipoId) => [
  for (final temporada in [2, 3, 4])
    for (var split = 0; split < 2; split++)
      RegistroCampeon(
        temporada: temporada,
        juego: Juego.lol,
        descripcion: 'Liga (Split ${split + 1})',
        tipo: TipoCampeon.liga,
        ganadorId: equipoId,
      ),
];

void main() {
  group('anti-dinastía con jugadores representados', () {
    test(
      'genera una oferta por la cláusula y no cambia al jugador de club',
      () {
        final objetivo = _jugador(
          'p1',
          equipoId: 'dinastia',
          representadoPorMi: true,
          habilidad: 90,
        )..valorMercado = 500000;
        final equipoDinastia = _equipo('dinastia', prestigio: 90);
        final comprador = _equipo('rival', prestigio: 85);
        final estado = _estado(
          jugadores: [objetivo],
          equipos: [equipoDinastia, comprador],
          temporada: 7,
          palmares: _titulosDeDinastia('dinastia'),
        );
        final indiceEquipos = {for (final e in estado.equipos) e.id: e};
        final indiceJugadores = {for (final j in estado.jugadores) j.id: j};

        final resultado = procesarMercadoIA(
          estado: estado,
          indiceEquipos: indiceEquipos,
          indiceJugadores: indiceJugadores,
          rnd: Random(1),
          nuevoIdJugador: () => 'nuevo',
        );

        // La seguridad principal: el representado sigue en su club.
        expect(objetivo.equipoId, 'dinastia');
        expect(objetivo.temporadaUltimoTraspaso, isNull);

        // La dinastía no lo ignora: llega una oferta con la cláusula (40 %).
        final ofertas = estado.ofertas
            .where((o) => o.jugadorId == 'p1')
            .toList();
        expect(ofertas, hasLength(1));
        final oferta = ofertas.single;
        expect(oferta.tipo, TipoOferta.traspaso);
        expect(oferta.equipoId, 'rival');
        expect(oferta.equipoOrigenId, 'dinastia');
        expect(oferta.monto, 200000);
        expect(oferta.montoMaximo, 700000);
        expect(resultado.ofertas, contains(oferta));
        expect(resultado.fichajesCerrados, 0);
        // El comprador todavía no pagó nada.
        expect(comprador.presupuesto, 1000000);
      },
    );

    test('M14: solo los títulos de 1ª División cuentan como dinastía', () {
      final estado =
          _estado(
              jugadores: const [],
              equipos: [
                _equipo('dinastia1'),
                _equipo('dinastia2', prestigio: 55, division: 2),
              ],
            )
            ..competiciones.addAll([
              Competicion(
                juego: Juego.lol,
                region: 'Test',
                division: 1,
                liga: 'Liga Primera',
                equipoIds: ['dinastia1'],
              ),
              Competicion(
                juego: Juego.lol,
                region: 'Test',
                division: 2,
                liga: 'Liga Segunda',
                equipoIds: ['dinastia2'],
              ),
            ]);

      RegistroCampeon titulo(String equipoId, String liga) => RegistroCampeon(
        temporada: 2,
        juego: Juego.lol,
        descripcion: '$liga (Split 1)',
        tipo: TipoCampeon.liga,
        ganadorId: equipoId,
      );

      expect(
        tituloEsDePrimeraDivision(estado, titulo('dinastia1', 'Liga Primera')),
        isTrue,
      );
      expect(
        tituloEsDePrimeraDivision(estado, titulo('dinastia2', 'Liga Segunda')),
        isFalse,
      );
    });

    test('no genera ofertas duplicadas de la misma dinastía', () {
      final objetivo = _jugador(
        'p1',
        equipoId: 'dinastia',
        representadoPorMi: true,
        habilidad: 90,
      )..valorMercado = 500000;
      final estado = _estado(
        jugadores: [objetivo],
        equipos: [
          _equipo('dinastia', prestigio: 90),
          _equipo('rival', prestigio: 85),
        ],
        temporada: 7,
        palmares: _titulosDeDinastia('dinastia'),
      );
      estado.ofertas.add(
        Oferta(
          id: 'of_existente',
          tipo: TipoOferta.traspaso,
          jugadorId: 'p1',
          equipoId: 'rival',
          equipoOrigenId: 'dinastia',
          monto: 200000,
          salarioAnual: 125000,
          semanasRestantes: 2,
          temporada: 7,
          semana: 1,
        ),
      );

      procesarMercadoIA(
        estado: estado,
        indiceEquipos: {for (final e in estado.equipos) e.id: e},
        indiceJugadores: {for (final j in estado.jugadores) j.id: j},
        rnd: Random(1),
        nuevoIdJugador: () => 'nuevo',
      );

      expect(estado.ofertas.where((o) => o.jugadorId == 'p1'), hasLength(1));
      expect(objetivo.equipoId, 'dinastia');
    });
  });

  group('fichajes juveniles de 2ª División (C3)', () {
    test('nunca ficha a un jugador representado', () {
      final representado = _jugador(
        'p1',
        representadoPorMi: true,
        region: 'Test',
      );
      final estado = _estado(
        jugadores: [representado],
        equipos: [_equipo('e2', division: 2)],
        temporada: 3,
      );

      ficharJovenesDeSegunda(estado: estado, rnd: Random(1), probabilidad: 1.0);

      expect(representado.equipoId, isNull);
      expect(representado.suplente, isFalse);
      expect(representado.temporadaUltimoTraspaso, isNull);
    });

    test('ficha a un joven libre y lo marca como recién traspasado', () {
      final joven = _jugador('p2', region: 'Test');
      final estado = _estado(
        jugadores: [joven],
        equipos: [_equipo('e2', division: 2)],
        temporada: 3,
      );

      ficharJovenesDeSegunda(estado: estado, rnd: Random(1), probabilidad: 1.0);

      expect(joven.equipoId, 'e2');
      expect(joven.suplente, isTrue);
      expect(joven.temporadaUltimoTraspaso, 3);
    });

    test('respeta la edad máxima de 21 años', () {
      final veterano = _jugador('p3', region: 'Test', edad: 25);
      final estado = _estado(
        jugadores: [veterano],
        equipos: [_equipo('e2', division: 2)],
      );

      ficharJovenesDeSegunda(estado: estado, rnd: Random(1), probabilidad: 1.0);

      expect(veterano.equipoId, isNull);
    });

    test('no supera el máximo de suplentes del equipo', () {
      final joven = _jugador('p4', region: 'Test');
      final estado = _estado(
        jugadores: [
          _jugador('s1', equipoId: 'e2', suplente: true),
          _jugador('s2', equipoId: 'e2', suplente: true),
          joven,
        ],
        equipos: [_equipo('e2', division: 2)],
      );

      ficharJovenesDeSegunda(estado: estado, rnd: Random(1), probabilidad: 1.0);

      expect(joven.equipoId, isNull);
    });
  });
}
