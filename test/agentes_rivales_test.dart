// Pruebas de la Parte 3A: agentes rivales, disputas, robos, "Convencerlo",
// reputación, ranking y Agente del Año.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/agentes_rivales.dart';
import 'package:esport_agent/logica/formulas.dart';
import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/logica/premios.dart';
import 'package:esport_agent/modelos/agente.dart';
import 'package:esport_agent/modelos/agente_rival.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/historial.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';
import 'package:esport_agent/modelos/noticia.dart';

/// Generador controlado: devuelve los enteros y dobles indicados en orden.
class _RandomFijo implements Random {
  _RandomFijo({List<int>? enteros, List<double>? dobles})
    : _enteros = List<int>.from(enteros ?? const [0]),
      _dobles = List<double>.from(dobles ?? const [0.0]);

  final List<int> _enteros;
  final List<double> _dobles;
  int _indiceEntero = 0;
  int _indiceDoble = 0;

  @override
  int nextInt(int max) {
    if (max <= 0) return 0;
    final valor = _enteros[_indiceEntero % _enteros.length];
    _indiceEntero++;
    return valor % max;
  }

  @override
  double nextDouble() {
    final valor = _dobles[_indiceDoble % _dobles.length];
    _indiceDoble++;
    return valor;
  }

  @override
  bool nextBool() => nextDouble() < 0.5;
}

Jugador _jugador(
  String id, {
  String? equipoId,
  bool representadoPorMi = false,
  String? agenteId,
  int habilidad = 60,
  int potencial = 80,
  int edad = 22,
  int satisfaccion = 70,
  int enfriamiento = 0,
  int espera = 0,
  int valor = 100000,
}) {
  final jugador = Jugador(
    id: id,
    nick: id,
    nombreReal: id,
    pais: 'Test',
    edad: edad,
    juego: Juego.lol,
    rol: 'Mid',
    habilidad: habilidad,
    potencial: potencial,
    equipoId: equipoId,
    salarioAnual: 25000,
    semanasContrato: equipoId == null ? 0 : 100,
    representadoPorMi: representadoPorMi,
    agenteId: agenteId,
    satisfaccion: satisfaccion,
    semanasEnfriamientoAgente: enfriamiento,
    semanasEsperaConvencer: espera,
  );
  jugador.valorMercado = valor;
  return jugador;
}

AgenteRival _rival(
  String id, {
  PerfilRival perfil = PerfilRival.agresivo,
  int reputacion = 60,
  int dinero = 1000000,
  Juego? juegoEspecialidad,
  String? nombre,
}) => AgenteRival(
  id: id,
  nombre: nombre ?? 'Rival $id',
  pais: 'Chile',
  perfil: perfil,
  juegoEspecialidad: juegoEspecialidad,
  reputacion: reputacion,
  dinero: dinero,
);

EstadoPartida _estado({
  required List<Jugador> jugadores,
  List<AgenteRival>? rivales,
  int reputacion = 50,
  int dinero = 1000000,
}) => EstadoPartida(
  agente: Agente(
    nombre: 'Mi agencia',
    pais: 'Chile',
    dinero: dinero,
    reputacion: reputacion,
  ),
  jugadores: jugadores,
  equipos: const [],
  noticias: [],
  agentesRivales: rivales,
);

MotorJuego _motor(EstadoPartida estado, {Random? random}) {
  final motor = MotorJuego(random: random ?? Random(20251019));
  motor.estado = estado;
  motor.reconstruirIndices();
  return motor;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('generación y cartera inicial', () {
    test('genera entre 15 y 25 rivales con ids/nombres únicos y perfiles', () {
      final jugadores = [
        for (var i = 0; i < 120; i++) _jugador('p$i', habilidad: 40),
        _jugador('mio', representadoPorMi: true, habilidad: 50),
      ];
      final estado = _estado(jugadores: jugadores);
      asegurarAgentesRivales(estado, Random(7));

      expect(
        estado.agentesRivales.length,
        inInclusiveRange(agentesRivalesMin, agentesRivalesMax),
      );
      final ids = estado.agentesRivales.map((r) => r.id).toSet();
      final nombres = estado.agentesRivales.map((r) => r.nombre).toSet();
      expect(ids.length, estado.agentesRivales.length);
      expect(nombres.length, estado.agentesRivales.length);

      var cazatalentos = 0;
      var especialistas = 0;
      for (final rival in estado.agentesRivales) {
        if (rival.perfil == PerfilRival.cazatalentos) cazatalentos++;
        if (rival.perfil == PerfilRival.especialista) {
          especialistas++;
          expect(rival.juegoEspecialidad, isNotNull);
        }
        final cartera = carteraDeRival(estado, rival);
        expect(cartera.length, greaterThanOrEqualTo(2));
        expect(cartera.length, lessThanOrEqualTo(5));
        expect(
          cartera.length,
          lessThanOrEqualTo(maxCarteraPorPerfil[rival.perfil]!),
        );
        for (final jugador in cartera) {
          expect(
            rival.reputacion,
            greaterThanOrEqualTo(jugador.habilidad - 40),
          );
        }
      }
      expect(cazatalentos, greaterThanOrEqualTo(2));
      expect(especialistas, greaterThanOrEqualTo(2));
      expect(estado.jugadores.firstWhere((j) => j.id == 'mio').sinAgente,
          isFalse);
    });

    test('serialización ida y vuelta y perfil desconocido', () {
      final original = _rival(
        'r001',
        perfil: PerfilRival.especialista,
        juegoEspecialidad: Juego.valorant,
        reputacion: 77,
        dinero: 123456,
      );
      final copia = AgenteRival.fromJson(original.toJson());
      expect(copia.id, original.id);
      expect(copia.nombre, original.nombre);
      expect(copia.perfil, PerfilRival.especialista);
      expect(copia.juegoEspecialidad, Juego.valorant);
      expect(copia.reputacion, 77);
      expect(copia.dinero, 123456);

      final invalido = AgenteRival.fromJson({
        'id': 'r002',
        'nombre': 'Raro',
        'pais': 'Chile',
        'perfil': 'no_existe',
        'reputacion': 150,
        'dinero': -5,
      });
      expect(invalido.perfil, PerfilRival.agresivo);
      expect(invalido.juegoEspecialidad, isNull);
      expect(invalido.reputacion, 100);
    });
  });

  group('disputa por un jugador sin agente', () {
    test('solo disputan rivales dentro de la ventaja y con cartera libre', () {
      final jugador = _jugador('p1');
      final dentro = _rival('r1', reputacion: 70);
      final fuera = _rival('r2', reputacion: 76);
      final lleno = _rival('r3', reputacion: 60, perfil: PerfilRival.conservador);
      final jugadores = [
        jugador,
        for (var i = 0; i < 8; i++)
          _jugador('r3_$i', agenteId: lleno.id, representadoPorMi: false),
      ];
      final estado = _estado(
        jugadores: jugadores,
        rivales: [dentro, fuera, lleno],
      );

      final elegibles = rivalesQuePuedenDisputar(estado, jugador);
      expect(elegibles.map((r) => r.id), contains(dentro.id));
      expect(elegibles.map((r) => r.id), isNot(contains(fuera.id)));
      expect(elegibles.map((r) => r.id), isNot(contains(lleno.id)));
    });

    test('gana el de mayor atractivo y solo el ganador paga', () async {
      final jugador = _jugador('p1');
      final rival = _rival('r1', reputacion: 70);
      final estado = _estado(
        jugadores: [jugador],
        rivales: [rival],
        reputacion: 50,
      );
      final motor = _motor(
        estado,
        random: _RandomFijo(dobles: [0.0], enteros: [0, 0, 10]),
      );
      final dineroMio = motor.agente.dinero;
      final dineroRival = rival.dinero;

      final resultado = await motor.reclutar(jugador);

      expect(resultado.huboDisputa, isTrue);
      expect(resultado.ganoRival, isTrue);
      expect(jugador.representadoPorMi, isFalse);
      expect(jugador.agenteId, rival.id);
      expect(jugador.semanasEnfriamientoAgente, 26);
      expect(motor.agente.dinero, dineroMio);
      expect(rival.dinero, dineroRival - costoFichajeRival(jugador));
    });

    test('si gano la disputa pago la comisión y el rival no paga', () async {
      final jugador = _jugador('p1');
      final rival = _rival('r1', reputacion: 55);
      final estado = _estado(
        jugadores: [jugador],
        rivales: [rival],
        reputacion: 50,
      );
      final motor = _motor(
        estado,
        random: _RandomFijo(dobles: [0.0], enteros: [0, 10, 0]),
      );
      final dineroMio = motor.agente.dinero;
      final dineroRival = rival.dinero;

      final resultado = await motor.reclutar(jugador);

      expect(resultado.ok, isTrue);
      expect(resultado.huboDisputa, isTrue);
      expect(resultado.ganoRival, isFalse);
      expect(jugador.representadoPorMi, isTrue);
      expect(jugador.agenteId, 'yo');
      expect(motor.agente.dinero, dineroMio - costoRepresentar(jugador.valorMercado));
      expect(rival.dinero, dineroRival);
    });
  });

  group('robo y convencer', () {
    test('roba solo a un representado insatisfecho y sin enfriamiento', () {
      final jugador = _jugador(
        'p1',
        representadoPorMi: true,
        agenteId: 'yo',
        satisfaccion: 20,
      );
      final rival = _rival('r1', reputacion: 80);
      final estado = _estado(jugadores: [jugador], rivales: [rival]);

      final resultado = ejecutarSemanaRivales(
        estado: estado,
        rnd: _RandomFijo(dobles: [0.0], enteros: [0]),
      );

      expect(resultado.robos, 1);
      expect(jugador.representadoPorMi, isFalse);
      expect(jugador.agenteId, rival.id);
      expect(jugador.semanasEnfriamientoAgente, 26);
      expect(resultado.avisosRobo, hasLength(1));
      expect(resultado.noticias.single.tipo, TipoNoticia.alerta);
    });

    test('no roba con satisfacción alta o con enfriamiento', () {
      final feliz = _jugador(
        'feliz',
        representadoPorMi: true,
        agenteId: 'yo',
        satisfaccion: 80,
      );
      final enfriado = _jugador(
        'enfriado',
        representadoPorMi: true,
        agenteId: 'yo',
        satisfaccion: 10,
        enfriamiento: 26,
      );
      final rival = _rival('r1', reputacion: 80);
      final estado = _estado(
        jugadores: [feliz, enfriado],
        rivales: [rival],
      );

      final resultado = ejecutarSemanaRivales(
        estado: estado,
        rnd: _RandomFijo(dobles: [0.0], enteros: [0]),
      );

      expect(resultado.robos, 0);
      expect(feliz.representadoPorMi, isTrue);
      expect(enfriado.representadoPorMi, isTrue);
    });

    test('convencer falla deja 13 semanas de espera y no se reintenta', () async {
      final jugador = _jugador('p1', agenteId: 'r1');
      final rival = _rival('r1', reputacion: 20);
      final estado = _estado(
        jugadores: [jugador],
        rivales: [rival],
        reputacion: 90,
      );
      final motor = _motor(
        estado,
        random: _RandomFijo(dobles: [0.99]),
      );

      final resultado = await motor.convencer(jugador);
      expect(resultado.ok, isFalse);
      expect(jugador.semanasEsperaConvencer, 13);
      expect(jugador.representadoPorMi, isFalse);
      expect(jugador.agenteId, rival.id);

      final segundo = await motor.convencer(jugador);
      expect(segundo.ok, isFalse);
      expect(segundo.mensaje, contains('13 semanas'));
    });

    test('convencer con éxito cambia de agente y deja enfriamiento 26', () async {
      final jugador = _jugador('p1', agenteId: 'r1');
      final rival = _rival('r1', reputacion: 20);
      final estado = _estado(
        jugadores: [jugador],
        rivales: [rival],
        reputacion: 90,
      );
      final motor = _motor(
        estado,
        random: _RandomFijo(dobles: [0.0]),
      );

      final resultado = await motor.convencer(jugador);
      expect(resultado.ok, isTrue);
      expect(jugador.representadoPorMi, isTrue);
      expect(jugador.agenteId, 'yo');
      expect(jugador.semanasEnfriamientoAgente, 26);
      expect(jugador.semanasEsperaConvencer, 0);
    });

    test('la probabilidad de convencer queda entre 0,05 y 0,60', () {
      final jugador = _jugador('p1', agenteId: 'r1');
      final bajo = _rival('r1', reputacion: 0);
      final alto = _rival('r2', reputacion: 100);
      expect(
        probabilidadConvencerJugador(
          estado: _estado(
            jugadores: [jugador],
            rivales: [alto],
            reputacion: 0,
          ),
          rival: alto,
          jugador: jugador,
        ),
        greaterThanOrEqualTo(0.05),
      );
      expect(
        probabilidadConvencerJugador(
          estado: _estado(
            jugadores: [jugador],
            rivales: [bajo],
            reputacion: 100,
          ),
          rival: bajo,
          jugador: jugador,
        ),
        lessThanOrEqualTo(0.60),
      );
    });
  });

  group('reputación, ranking y premios', () {
    test('la reputación de un rival se acota a 0–100', () {
      final rival = _rival('r1', reputacion: 99);
      ajustarReputacionRival(rival, 10);
      expect(rival.reputacion, 100);
      ajustarReputacionRival(rival, -200);
      expect(rival.reputacion, 0);
    });

    test('los títulos internacionales dan reputación una vez por rival', () {
      final rival = _rival('r1', reputacion: 50);
      final estado = _estado(
        jugadores: [
          _jugador('p1', equipoId: 'e1', agenteId: rival.id),
          _jugador('p2', equipoId: 'e1', agenteId: rival.id),
        ],
        rivales: [rival],
      );
      aplicarReputacionRivalesPorTitulo(estado, 'e1', mundial: true);
      expect(rival.reputacion, 55);
      aplicarReputacionRivalesPorTitulo(estado, 'e1', mundial: false);
      expect(rival.reputacion, 57);
    });

    test('el ranking incluye mi agencia y ordena por puntos y cartera', () {
      final estado = _estado(
        jugadores: [
          _jugador('mio', representadoPorMi: true, valor: 300000),
          _jugador('r1', agenteId: 'r1', valor: 100000),
          _jugador('r2', agenteId: 'r2', valor: 2000000),
        ],
        rivales: [
          _rival('r1', reputacion: 40),
          _rival('r2', reputacion: 55),
        ],
        reputacion: 60,
      );

      final ranking = rankingAgentes(estado);
      expect(ranking, hasLength(3));
      expect(ranking.any((f) => f.esYo), isTrue);
      expect(ranking.first.esYo, isTrue);
      expect(ranking.last.nombre, 'Rival r1');
    });

    test('el Agente del Año compara contra rivales y da +5 al ganador', () {
      final rival = _rival('r1', reputacion: 40);
      final estado = _estado(
        jugadores: [
          _jugador('p1', equipoId: 'e1', agenteId: rival.id),
          _jugador('p2', equipoId: 'e1', agenteId: rival.id),
        ],
        rivales: [rival],
        reputacion: 30,
      );
      estado.palmares.add(
        RegistroCampeon(
          temporada: 1,
          juego: Juego.lol,
          descripcion: 'Mundial',
          tipo: TipoCampeon.torneo,
          ganadorId: 'e1',
        ),
      );
      estado.premios.add(
        PremioIndividual(
          temporada: 1,
          juego: Juego.lol,
          categoria: CategoriaPremio.jugadorDelAnio,
          jugadorId: 'p1',
          detalle: 'Premio de prueba',
        ),
      );

      final premio = calcularAgenteDelAnio(estado);
      expect(premio, isNotNull);
      expect(premio!.nombreAgente, rival.nombre);
      expect(premio.detalle, contains('Podio:'));
      expect(premio.detalle, contains('2.')); // yo aparezco en el podio

      aplicarEfectosPremios(estado, [premio]);
      expect(rival.reputacion, 45);
      expect(estado.agente.reputacion, 30);
    });
  });

  test('el paso semanal de los rivales es rápido con 300+ sin agente', () {
    final jugadores = [
      for (var i = 0; i < 350; i++) _jugador('p$i', habilidad: 45),
    ];
    final rivales = [
      for (var i = 0; i < 18; i++)
        _rival('r$i', perfil: PerfilRival.agresivo, reputacion: 70),
    ];
    final estado = _estado(jugadores: jugadores, rivales: rivales);

    final cronometro = Stopwatch()..start();
    ejecutarSemanaRivales(estado: estado, rnd: Random(20251019));
    cronometro.stop();

    expect(cronometro.elapsedMilliseconds, lessThan(3000));
  });
}
