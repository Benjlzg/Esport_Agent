// Pruebas de la Parte 3C: potencial oculto, ojeadores, talentos ocultos,
// migración y uso del potencial estimado por rivales e IA.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/agentes_rivales.dart';
import 'package:esport_agent/logica/formulas.dart';
import 'package:esport_agent/logica/mantenimiento.dart';
import 'package:esport_agent/logica/mercado.dart';
import 'package:esport_agent/logica/ojeadores.dart';
import 'package:esport_agent/modelos/agente.dart';
import 'package:esport_agent/modelos/agente_rival.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';
import 'package:esport_agent/modelos/ojeador.dart';

import 'apoyo/entorno_simulacion.dart';

/// Generador controlado: repite en bucle los enteros y dobles indicados.
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

Equipo _equipo(
  String id, {
  Juego juego = Juego.lol,
  String region = 'Corea',
  int division = 1,
}) => Equipo(
  id: id,
  nombre: id.toUpperCase(),
  juego: juego,
  region: region,
  division: division,
  prestigio: 70,
  presupuesto: 10000000,
  colorPrincipal: 0xFF000000,
  escudo: 'x.png',
);

Jugador _jugador(
  String id, {
  Juego juego = Juego.lol,
  String? region = 'Corea',
  String? equipoId,
  bool representadoPorMi = false,
  String? agenteId,
  int habilidad = 60,
  int potencial = 80,
  int error = 0,
  int? visibleMin,
  int? visibleMax,
  bool oculto = false,
  int edad = 20,
  int valor = 100000,
}) {
  final jugador = Jugador(
    id: id,
    nick: id,
    nombreReal: id,
    pais: 'Test',
    edad: edad,
    juego: juego,
    rol: juego.roles.first,
    habilidad: habilidad,
    potencial: potencial,
    errorPotencial: error,
    potencialVisibleMin: visibleMin,
    potencialVisibleMax: visibleMax,
    oculto: oculto,
    equipoId: equipoId,
    region: region,
    salarioAnual: equipoId == null ? 0 : 100000,
    semanasContrato: equipoId == null ? 0 : 100,
    representadoPorMi: representadoPorMi,
    agenteId: agenteId,
  );
  jugador.valorMercado = valor;
  return jugador;
}

EstadoPartida _estado({
  required List<Jugador> jugadores,
  List<Equipo>? equipos,
  List<AgenteRival>? rivales,
  int dinero = 1000000,
  int temporada = 1,
}) => EstadoPartida(
  agente: Agente(nombre: 'Mi agencia', pais: 'Chile', dinero: dinero),
  jugadores: jugadores,
  equipos: equipos ?? [_equipo('e1')],
  noticias: [],
  agentesRivales: rivales,
  semana: 1,
  temporada: temporada,
);

AgenteRival _rival({
  String id = 'r001',
  PerfilRival perfil = PerfilRival.cazatalentos,
  int reputacion = 80,
  int dinero = 1000000,
}) => AgenteRival(
  id: id,
  nombre: 'Rival $id',
  pais: 'Chile',
  perfil: perfil,
  reputacion: reputacion,
  dinero: dinero,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('textoPotencial y punto medio', () {
    test('usa el rango visible y cae al exacto si no hay rango', () {
      final jugador = _jugador('p1', potencial: 80);
      expect(textoPotencial(jugador), '80');
      expect(puntoMedioPotencial(jugador), 80);
      expect(semianchoVisibleDe(jugador), 0);

      jugador.potencialVisibleMin = 72;
      jugador.potencialVisibleMax = 88;
      expect(textoPotencial(jugador), '72–88');
      expect(puntoMedioPotencial(jugador), 80);
      expect(semianchoVisibleDe(jugador), 8);

      jugador.potencialVisibleMax = 72;
      expect(textoPotencial(jugador), '72');
    });
  });

  group('fórmula del semiancho', () {
    test('niveles 1–5 y semanas 0–20', () {
      expect(semianchoPotencialVisible(nivelMejor: 0, semanasObservado: 0), 15);
      expect(semianchoPotencialVisible(nivelMejor: 1, semanasObservado: 4), 11);
      expect(semianchoPotencialVisible(nivelMejor: 3, semanasObservado: 8), 5);
      expect(semianchoPotencialVisible(nivelMejor: 5, semanasObservado: 10), 0);
      expect(semianchoPotencialVisible(nivelMejor: 5, semanasObservado: 20), 0);
      // Los valores fuera de rango se acotan.
      expect(semianchoPotencialVisible(nivelMejor: 9, semanasObservado: 99), 0);
    });

    test('el rango siempre contiene al potencial y respeta habilidad–99', () {
      for (var error = -15; error <= 15; error++) {
        for (var nivel = 0; nivel <= 5; nivel++) {
          for (var semanas = 0; semanas <= 20; semanas++) {
            final jugador = _jugador(
              'p$error-$nivel-$semanas',
              habilidad: 40,
              potencial: 75,
              error: error,
            );
            final rango = rangoPotencialVisible(
              jugador: jugador,
              nivelMejor: nivel,
              semanasObservado: semanas,
            );
            expect(rango.min, greaterThanOrEqualTo(40));
            expect(rango.max, lessThanOrEqualTo(99));
            expect(rango.min, lessThanOrEqualTo(75));
            expect(rango.max, greaterThanOrEqualTo(75));
          }
        }
      }
    });
  });

  group('error de potencial', () {
    test('se asigna una sola vez y el rango inicial es ±15', () {
      final rnd = Random(7);
      final jugador = _jugador(
        'p1',
        habilidad: 40,
        potencial: 50,
        visibleMin: null,
        visibleMax: null,
      );
      inicializarPotencialJugador(jugador, rnd);
      final error = jugador.errorPotencial;
      final minimo = jugador.potencialVisibleMin;
      final maximo = jugador.potencialVisibleMax;
      expect(error, inInclusiveRange(-15, 15));
      expect(minimo, isNotNull);
      expect(maximo, isNotNull);
      expect(minimo!, lessThanOrEqualTo(50));
      expect(maximo!, greaterThanOrEqualTo(50));
      expect(minimo, greaterThanOrEqualTo(40));
      expect(maximo, lessThanOrEqualTo(99));

      // Llamarla otra vez con otro RNG no vuelve a sortear nada.
      inicializarPotencialJugador(jugador, Random(999));
      expect(jugador.errorPotencial, error);
      expect(jugador.potencialVisibleMin, minimo);
      expect(jugador.potencialVisibleMax, maximo);
    });

    test('el hash de migración cubre [-15, 15] con buena distribución', () {
      final frecuencia = <int, int>{};
      for (var i = 0; i < 10000; i++) {
        final valor = errorPotencialDeterminista(
          'p${i.toString().padLeft(4, '0')}',
        );
        expect(valor, inInclusiveRange(-15, 15));
        frecuencia[valor] = (frecuencia[valor] ?? 0) + 1;
      }
      expect(frecuencia.keys.toSet(), {
        for (var valor = -15; valor <= 15; valor++) valor,
      });
      // Con 10.000 ids, cada valor debería salir alrededor de 322 veces.
      for (final cantidad in frecuencia.values) {
        expect(cantidad, inInclusiveRange(180, 480));
      }
      expect(
        errorPotencialDeterminista('p0000'),
        errorPotencialDeterminista('p0000'),
      );
    });
  });

  group('observación semanal', () {
    test('se estrecha de forma monótona y no se reabre', () {
      final jugador = _jugador('p1', habilidad: 40, potencial: 85, error: 10);
      final inicial = rangoPotencialVisible(
        jugador: jugador,
        nivelMejor: 0,
        semanasObservado: 0,
      );
      jugador.potencialVisibleMin = inicial.min;
      jugador.potencialVisibleMax = inicial.max;

      var anterior =
          jugador.potencialVisibleMax! - jugador.potencialVisibleMin!;
      for (var semana = 1; semana <= 10; semana++) {
        observarJugadorSemanal(jugador, nivelMejor: 5);
        final ancho =
            jugador.potencialVisibleMax! - jugador.potencialVisibleMin!;
        expect(ancho, lessThanOrEqualTo(anterior));
        expect(jugador.potencialVisibleMin!, lessThanOrEqualTo(85));
        expect(jugador.potencialVisibleMax!, greaterThanOrEqualTo(85));
        anterior = ancho;
      }
      expect(jugador.potencialVisibleMin, 85);
      expect(jugador.potencialVisibleMax, 85);
      expect(jugador.semanasObservado, 10);

      // Al dejar de estar cubierto conserva lo ya descubierto.
      observarJugadorSemanal(jugador, nivelMejor: 0);
      expect(jugador.potencialVisibleMin, 85);
      expect(jugador.potencialVisibleMax, 85);
      expect(jugador.semanasObservado, 10);
    });

    test('solo sube semanasObservado para cubiertos, con tope 20', () {
      final cubierto = _jugador('cubierto', region: 'Corea');
      final fuera = _jugador('fuera', region: 'Europa');
      inicializarPotencialJugador(cubierto, Random(1));
      inicializarPotencialJugador(fuera, Random(2));
      final cobertura = nivelesDeCobertura([
        Ojeador(
          id: 'o001',
          nombre: 'Ojeador',
          juego: Juego.lol,
          region: 'Corea',
          nivel: 2,
        ),
      ]);
      final equipos = {'e1': _equipo('e1')};
      expect(
        nivelDeCoberturaDeJugador(
          jugador: cubierto,
          cobertura: cobertura,
          equipos: equipos,
        ),
        2,
      );
      expect(
        nivelDeCoberturaDeJugador(
          jugador: fuera,
          cobertura: cobertura,
          equipos: equipos,
        ),
        0,
      );

      for (var i = 0; i < 25; i++) {
        observarJugadorSemanal(cubierto, nivelMejor: 1);
        observarJugadorSemanal(fuera, nivelMejor: 0);
      }
      expect(cubierto.semanasObservado, 20);
      expect(fuera.semanasObservado, 0);
    });

    test('la nota de precisión distingue ojeador, sin ojeador y exacto', () {
      final jugador = _jugador(
        'p1',
        region: 'Corea',
        visibleMin: 70,
        visibleMax: 90,
      );
      final ojeador = Ojeador(
        id: 'o001',
        nombre: 'Ojeador',
        juego: Juego.lol,
        region: 'Corea',
        nivel: 3,
      );
      expect(
        notaPrecisionPotencial(
          jugador: jugador,
          ojeadores: [ojeador],
          equipos: {'e1': _equipo('e1')},
        ),
        'Ojeador nivel 3 · 0 semanas',
      );
      jugador.semanasObservado = 6;
      expect(
        notaPrecisionPotencial(
          jugador: jugador,
          ojeadores: [ojeador],
          equipos: {'e1': _equipo('e1')},
        ),
        'Ojeador nivel 3 · 6 semanas',
      );
      expect(
        notaPrecisionPotencial(
          jugador: jugador,
          ojeadores: const [],
          equipos: {'e1': _equipo('e1')},
        ),
        'Sin ojeador · 6 semanas observadas',
      );
    });
  });

  group('talentos ocultos', () {
    test(
      'solo se ven con ojeador, se destapan y el mantenimiento los protege',
      () {
        final estado = _estado(
          jugadores: [
            _jugador('libre1', region: 'Corea'),
            _jugador('libre2', region: 'Corea'),
          ],
          equipos: [_equipo('e1', region: 'Corea')],
        );
        final ocultos = generarTalentosOcultos(estado, Random(3));
        expect(ocultos, hasLength(1));
        final oculto = ocultos.first;
        expect(oculto.oculto, isTrue);
        expect(oculto.edad, inInclusiveRange(16, 20));
        expect(oculto.habilidad, inInclusiveRange(25, 40));
        expect(oculto.potencial, inInclusiveRange(70, 99));
        expect(oculto.potencialVisibleMin, isNotNull);
        expect(oculto.potencialVisibleMax, isNotNull);

        expect(talentosOcultosVisibles(estado), isEmpty);
        estado.ojeadores.add(
          Ojeador(
            id: 'o001',
            nombre: 'Ojeador',
            juego: Juego.lol,
            region: 'Corea',
            nivel: 1,
          ),
        );
        expect(talentosOcultosVisibles(estado), hasLength(1));

        // El tope de 300 no puede borrarlo.
        estado.jugadores.addAll([
          _jugador('normal1', region: 'Corea'),
          _jugador('normal2', region: 'Corea'),
          _jugador('normal3', region: 'Corea'),
        ]);
        limpiarDatosAntiguos(estado, limiteLibres: 1);
        expect(
          estado.jugadores.any((j) => j.id == oculto.id),
          isTrue,
          reason: 'El talento oculto debe quedar protegido del tope.',
        );

        expect(destaparTalentosOcultos(estado), 1);
        expect(oculto.oculto, isFalse);
        expect(talentosOcultosVisibles(estado), isEmpty);
      },
    );

    test('ni la IA de 2ª División ni los rivales fichan ocultos', () {
      final equipo = _equipo('e1', division: 2, region: 'Corea');
      final estado = _estado(jugadores: [], equipos: [equipo]);
      final ocultos = generarTalentosOcultos(estado, Random(4));
      expect(ocultos, hasLength(1));
      final oculto = ocultos.first;

      // La IA de 2ª División intenta fichar con probabilidad 1.
      ficharJovenesDeSegunda(estado: estado, rnd: Random(5), probabilidad: 1.0);
      expect(oculto.equipoId, isNull);

      // Un rival cazatalentos con actividad garantizada tampoco lo ve.
      final rival = _rival();
      estado.agentesRivales.add(rival);
      ejecutarSemanaRivales(
        estado: estado,
        rnd: _RandomFijo(dobles: [0.0, 1.0]),
      );
      expect(oculto.agenteId, isNull);
    });
  });

  group('rivales y potencial estimado', () {
    test('el cazatalentos usa potencialEstimado, no el potencial real', () {
      final flojo = _jugador(
        'flojo',
        habilidad: 70,
        potencial: 90,
        error: -15,
        edad: 18,
      );
      final estimado = _jugador(
        'estimado',
        habilidad: 70,
        potencial: 75,
        error: 15,
        edad: 18,
      );
      final oculto = _jugador(
        'oculto',
        habilidad: 70,
        potencial: 99,
        error: 0,
        edad: 18,
        oculto: true,
      );
      final rival = _rival();
      final estado = _estado(
        jugadores: [flojo, estimado, oculto],
        equipos: const [],
        rivales: [rival],
      );

      ejecutarSemanaRivales(
        estado: estado,
        rnd: _RandomFijo(dobles: [0.0, 1.0]),
      );

      expect(estimado.agenteId, rival.id);
      expect(flojo.agenteId, isNull);
      expect(oculto.agenteId, isNull);
      expect(potencialEstimadoDe(flojo), 75);
      expect(potencialEstimadoDe(estimado), 90);
    });
  });

  group('contratación y salario', () {
    test(
      'respeta el máximo, cobra el salario y deja de cobrarlo al despedir',
      () async {
        final motor = await crearPartidaSembrada(dinero: 1000000);
        final equipo = motor.equipos.firstWhere((e) => e.juego == Juego.lol);
        final juego = equipo.juego;
        final region = equipo.region;

        final resultado = await motor.contratarOjeador(
          juego: juego,
          region: region,
          nivel: 2,
        );
        expect(resultado.ok, isTrue);
        expect(motor.ojeadores, hasLength(1));
        expect(motor.gastoOjeadoresSemanal, 200);
        expect(motor.cuposOjeadores, 5);

        // Completa los 6 cupos y comprueba que el séptimo se rechaza.
        for (var i = 0; i < 5; i++) {
          final extra = await motor.contratarOjeador(
            juego: juego,
            region: region,
            nivel: 2,
          );
          expect(extra.ok, isTrue);
        }
        expect(motor.ojeadores, hasLength(6));
        expect(motor.cuposOjeadores, 0);
        expect(motor.gastoOjeadoresSemanal, 1200);
        final septimo = await motor.contratarOjeador(
          juego: juego,
          region: region,
          nivel: 2,
        );
        expect(septimo.ok, isFalse);

        final gastosAntes = motor.estado!.gastosUltimaSemana;
        await motor.avanzarSemana();
        expect(
          motor.estado!.gastosUltimaSemana,
          greaterThanOrEqualTo(gastoOficinaSemanal + 1200),
          reason: 'El salario de los ojeadores debe estar en los gastos.',
        );
        expect(motor.estado!.gastosUltimaSemana, greaterThan(gastosAntes));
        expect(motor.ojeadores.first.semanasContratado, 1);

        final despedido = await motor.despedirOjeador(motor.ojeadores.first);
        expect(despedido.ok, isTrue);
        expect(motor.ojeadores, hasLength(5));
        expect(motor.gastoOjeadoresSemanal, 1000);

        await motor.avanzarSemana();
        expect(
          motor.estado!.gastosUltimaSemana,
          greaterThanOrEqualTo(gastoOficinaSemanal + 1000),
        );
      },
    );
  });

  test(
    'tras 3 temporadas, muy pocos jugadores tienen errorPotencial = 0',
    () async {
      final motor = await crearPartidaSembrada(dinero: 1000000000);
      await motor.avanzarSemanas(156);
      final jugadores = motor.jugadores;
      expect(jugadores, isNotEmpty);
      expect(
        jugadores.every(
          (j) => j.potencialVisibleMin != null && j.potencialVisibleMax != null,
        ),
        isTrue,
        reason: 'Todos los jugadores nuevos deben nacer con rango inicial.',
      );
      final cero = jugadores.where((j) => j.errorPotencial == 0).length;
      expect(
        cero / jugadores.length,
        lessThanOrEqualTo(0.10),
        reason:
            'Demasiados jugadores con errorPotencial = 0 tras 3 temporadas.',
      );
    },
  );
}
