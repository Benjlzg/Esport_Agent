// Pruebas de la Parte 3E (academia).
//
// Cubren la generación de candidatos, el reclutamiento, el mantenimiento
// semanal, la progresión, la colocación en 2ª División y el aislamiento de los
// jóvenes de todos los sistemas que no deben tocarlos.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/academia.dart';
import 'package:esport_agent/logica/agentes_rivales.dart' as rivales;
import 'package:esport_agent/logica/eventos.dart';
import 'package:esport_agent/logica/formulas.dart';
import 'package:esport_agent/logica/mantenimiento.dart';
import 'package:esport_agent/logica/mercado.dart';
import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/logica/negociacion.dart';
import 'package:esport_agent/logica/ojeadores.dart';
import 'package:esport_agent/logica/progresion.dart';
import 'package:esport_agent/logica/satisfaccion.dart' as sat;
import 'package:esport_agent/logica/staff.dart' as staff_logica;
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';
import 'package:esport_agent/modelos/staff.dart';

import 'apoyo/entorno_simulacion.dart';

/// Crea una partida con dinero suficiente y sin rivales para las pruebas que
/// no miden la competencia de la Parte 3A.
Future<MotorJuego> _motor({bool conRivales = false}) async {
  final motor = await crearPartidaSembrada(dinero: 5000000);
  motor.agente.dinero = 5000000;
  if (!conRivales) motor.estado!.agentesRivales.clear();
  return motor;
}

/// Recluta a un candidato de la academia y comprueba que la acción funciona.
Future<Jugador> _reclutarAcademia(MotorJuego motor, Jugador candidato) async {
  final resultado = await motor.reclutarJovenAcademia(candidato);
  expect(resultado.ok, isTrue, reason: resultado.mensaje);
  return candidato;
}

/// Deja al joven listo para colocarse salvo la condición que pruebe el test.
void _prepararParaColocar(Jugador joven) {
  joven.edad = 17;
  joven.habilidad = 50;
  joven.potencial = max(60, joven.habilidad);
  joven.semanasEnAcademia = semanasEntrenamientoMinimo;
  joven.valorMercado = valorMercadoDe(joven);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('candidatos', () {
    test('genera 8 candidatos, 2 por videojuego y con edades 15–17', () async {
      final motor = await _motor();
      final candidatos = motor.candidatosAcademia;

      expect(candidatos, hasLength(jovenesAcademiaPorTemporada));
      for (final juego in Juego.values) {
        expect(
          candidatos.where((j) => j.juego == juego),
          hasLength(2),
          reason: 'Debe haber 2 candidatos de ${juego.nombre}.',
        );
      }
      for (final candidato in candidatos) {
        expect(candidato.candidatoAcademia, isTrue);
        expect(candidato.enAcademia, isFalse);
        expect(candidato.edad, inInclusiveRange(15, 17));
        expect(candidato.habilidad, inInclusiveRange(25, 45));
        expect(candidato.potencial, inInclusiveRange(60, 95));
        expect(candidato.potencial, greaterThanOrEqualTo(candidato.habilidad));
      }
    });

    test('el rango inicial es ±15 y el ojeador solo cubre juego+región', () async {
      final motor = await _motor();
      final candidato = motor.candidatosAcademia.first;
      expect(semianchoVisibleDe(candidato), 15);

      // Un ojeador de otro juego o de otra región no lo observa.
      final nivelOtroJuego = nivelDeCoberturaDeJugador(
        jugador: candidato,
        cobertura: {
          '${candidato.juego == Juego.lol ? Juego.valorant.name : Juego.lol.name}'
                  '|${candidato.region ?? ''}':
              5,
        },
        equipos: motor.indices.equipos,
      );
      expect(nivelOtroJuego, 0);
      observarJugadorSemanal(candidato, nivelMejor: nivelOtroJuego);
      expect(semianchoVisibleDe(candidato), 15);

      final nivelCorrecto = nivelDeCoberturaDeJugador(
        jugador: candidato,
        cobertura: {'${candidato.juego.name}|${candidato.region ?? ''}': 2},
        equipos: motor.indices.equipos,
      );
      expect(nivelCorrecto, 2);
      observarJugadorSemanal(candidato, nivelMejor: nivelCorrecto);
      expect(semianchoVisibleDe(candidato), lessThan(15));
    });

    test('no aparecen en el Mercado normal', () async {
      final motor = await _motor();
      final visibles = motor.jugadores.where((j) => j.candidatoAcademia);
      expect(visibles, isNotEmpty);
      // El filtro del Mercado los excluye igual que a los talentos ocultos.
      for (final candidato in visibles) {
        expect(candidato.oculto, isFalse);
        expect(candidato.sinAgente, isTrue);
      }
      final mercado = motor.jugadores.where(
        (j) => !j.oculto && !j.candidatoAcademia && j.sinAgente,
      );
      expect(mercado.any((j) => visibles.any((c) => c.id == j.id)), isFalse);
    });
  });

  group('reclutamiento y semana', () {
    test(r'recluta hasta 4 plazas y cobra $500 por joven', () async {
      final motor = await _motor();
      final dineroInicial = motor.agente.dinero;
      final candidatos = List<Jugador>.of(motor.candidatosAcademia);

      for (var i = 0; i < capacidadAcademia; i++) {
        await _reclutarAcademia(motor, candidatos[i]);
      }
      expect(motor.jovenesAcademia, hasLength(capacidadAcademia));
      expect(
        dineroInicial - motor.agente.dinero,
        capacidadAcademia * costoFichajeAcademia,
      );

      final quinto = await motor.reclutarJovenAcademia(candidatos[4]);
      expect(quinto.ok, isFalse);
      expect(motor.jovenesAcademia, hasLength(capacidadAcademia));
    });

    test(
      'el joven entra sin expectativas, sin contrato corriendo y sin cartera',
      () async {
        final motor = await _motor();
        final antesRanking = motor.rankingAgentes
            .firstWhere((fila) => fila.esYo)
            .representados;
        final joven = await _reclutarAcademia(
          motor,
          motor.candidatosAcademia.first,
        );

        expect(joven.enAcademia, isTrue);
        expect(joven.candidatoAcademia, isFalse);
        expect(joven.representadoPorMi, isTrue);
        expect(joven.agenteId, 'yo');
        expect(joven.expectativas, isEmpty);
        expect(joven.quiereHablar, isFalse);
        expect(joven.semanasContratoRepresentacion, 52);

        // No cuenta para la cartera normal ni para el ranking de agentes.
        expect(motor.misJugadores, isEmpty);
        expect(
          motor.rankingAgentes.firstWhere((fila) => fila.esYo).representados,
          antesRanking,
        );
        expect(rivales.valorCarteraMia(motor.estado!), 0);
      },
    );

    test(
      r'cobra $150 por joven y semana y no paga comisión de salario',
      () async {
        final motor = await _motor();
        await _reclutarAcademia(motor, motor.candidatosAcademia[0]);
        await _reclutarAcademia(motor, motor.candidatosAcademia[1]);
        expect(motor.gastoAcademiaSemanal, 2 * costoSemanalAcademiaPorJoven);

        final dineroAntes = motor.agente.dinero;
        final semanaAntes = motor.semana;
        await motor.avanzarSemana();

        expect(motor.semana, semanaAntes + 1);
        expect(motor.gastoAcademiaSemanal, 2 * costoSemanalAcademiaPorJoven);
        expect(motor.metricas.comisionesSalarioUltimaSemana, 0);
        expect(
          dineroAntes - motor.agente.dinero,
          greaterThanOrEqualTo(
            gastoOficinaSemanal + 2 * costoSemanalAcademiaPorJoven,
          ),
        );
        for (final joven in motor.jovenesAcademia) {
          expect(joven.expectativas, isEmpty);
          expect(joven.quiereHablar, isFalse);
          expect(joven.semanasContratoRepresentacion, 52);
          expect(joven.semanasEnAcademia, 1);
        }
      },
    );

    test(
      'el semiancho baja por semanas de academia aunque no haya ojeador',
      () async {
        final motor = await _motor();
        final joven = await _reclutarAcademia(
          motor,
          motor.candidatosAcademia.first,
        );
        joven.semanasEnAcademia = 4;
        final antes = semianchoVisibleDe(joven);
        observarPotencialAcademia(joven);
        expect(semianchoVisibleDe(joven), lessThan(antes));
        expect(semianchoVisibleDe(joven), 13);

        // Aunque se calcule otra vez con menos semanas, nunca se reabre.
        joven.semanasEnAcademia = 2;
        observarPotencialAcademia(joven);
        expect(semianchoVisibleDe(joven), lessThanOrEqualTo(13));
      },
    );

    test('el preparador no se apila con el bonus de la academia', () async {
      final motor = await _motor();
      final joven = await _reclutarAcademia(
        motor,
        motor.candidatosAcademia.first,
      );
      await motor.contratarStaff(RolStaff.preparador);
      final preparador = motor.miembroStaff(RolStaff.preparador)!;
      while (preparador.nivel < 5) {
        await motor.mejorarStaff(preparador);
      }

      expect(
        staff_logica.multiplicadorProgresionPreparador(
          motor.estado!,
          joven,
          enAcademia: true,
        ),
        1.0,
      );
      expect(bonusProgresionAcademia, 1.5);
      expect(
        probabilidadProgresoSemanal(
          joven,
          multiplicador: bonusProgresionAcademia,
        ),
        greaterThan(probabilidadProgresoSemanal(joven)),
      );
    });

    test(
      'un joven de academia progresa más que uno libre equivalente',
      () async {
        Jugador base({required bool academia}) => Jugador(
          id: academia ? 'academia' : 'libre',
          nick: academia ? 'Academia' : 'Libre',
          nombreReal: 'Prueba',
          pais: 'Chile',
          edad: 17,
          juego: Juego.lol,
          rol: Juego.lol.roles.first,
          habilidad: 30,
          potencial: 99,
          equipoId: null,
          salarioAnual: 0,
          semanasContrato: 0,
        );

        final academia = base(academia: true);
        final libre = base(academia: false);
        // Un dado fijo de 0,06 supera la probabilidad del joven libre (0,05)
        // pero no la de la academia (0,075). Así la comparación no depende de
        // la suerte de una semilla concreta.
        final rndAcademia = _DadoFijo(0.06);
        final rndLibre = _DadoFijo(0.06);
        for (var semana = 0; semana < 52; semana++) {
          aplicarProgresoSemanal(
            academia,
            rndAcademia,
            multiplicadorProbabilidad: bonusProgresionAcademia,
          );
          aplicarProgresoSemanal(libre, rndLibre);
        }

        expect(academia.habilidad, greaterThan(libre.habilidad));
      },
    );

    test('a los 18 sin colocar puede irse y queda como agente libre', () async {
      final motor = await _motor();
      final joven = await _reclutarAcademia(
        motor,
        motor.candidatosAcademia.first,
      );
      joven.edad = 18;
      final rnd = Random(4);
      for (var i = 0; i < 80 && joven.enAcademia; i++) {
        procesarSemanaAcademia(motor.estado!, rnd);
      }

      expect(joven.enAcademia, isFalse);
      expect(joven.representadoPorMi, isFalse);
      expect(joven.agenteId, isNull);
      expect(joven.equipoId, isNull);
      expect(joven.candidatoAcademia, isFalse);
    });

    test('soltar deja al joven libre y sin agente', () async {
      final motor = await _motor();
      final joven = await _reclutarAcademia(
        motor,
        motor.candidatosAcademia.first,
      );
      final resultado = await motor.soltarJovenAcademia(joven);
      expect(resultado.ok, isTrue);
      expect(joven.enAcademia, isFalse);
      expect(joven.representadoPorMi, isFalse);
      expect(joven.agenteId, isNull);
      expect(joven.equipoId, isNull);
    });
  });

  group('colocación', () {
    test(
      'solo permite equipos de 2ª División y cobra los derechos de formación',
      () async {
        final motor = await _motor();
        motor.estado!.semana = 1;
        final joven = await _reclutarAcademia(
          motor,
          motor.candidatosAcademia.first,
        );
        _prepararParaColocar(joven);
        final equipos = motor.equiposParaColocar(joven);
        expect(equipos, isNotEmpty);
        for (final equipo in equipos) {
          expect(equipo.division, 2);
          expect(equipo.juego, joven.juego);
          expect(equipo.presupuesto, greaterThanOrEqualTo(joven.valorMercado));
        }

        final equipo = equipos.first;
        final presupuestoEquipoAntes = equipo.presupuesto;
        final dineroAgenteAntes = motor.agente.dinero;
        final presupuestoTotalAntes = motor.equipos.fold<int>(
          0,
          (suma, e) => suma + e.presupuesto,
        );

        final resultado = await motor.colocarJovenAcademia(joven, equipo);
        expect(resultado.ok, isTrue, reason: resultado.mensaje);

        final derechos = (joven.valorMercado * porcentajeDerechosFormacion)
            .round();
        expect(motor.agente.dinero - dineroAgenteAntes, derechos);
        expect(
          derechos,
          greaterThan(comisionPorTransferencia(joven.valorMercado)),
        );
        expect(presupuestoEquipoAntes - equipo.presupuesto, joven.valorMercado);
        // No hay club vendedor: la suma de presupuestos solo baja por el pago.
        final presupuestoTotalDespues = motor.equipos.fold<int>(
          0,
          (suma, e) => suma + e.presupuesto,
        );
        expect(
          presupuestoTotalAntes - presupuestoTotalDespues,
          joven.valorMercado,
        );

        expect(joven.enAcademia, isFalse);
        expect(joven.candidatoAcademia, isFalse);
        expect(joven.equipoId, equipo.id);
        expect(joven.semanasContrato, 52);
        expect(joven.semanasContratoRepresentacion, 52);
        expect(joven.comisionSalarioContrato, 0.05);
        expect(joven.expectativas, isNotEmpty);
        expect(joven.quiereHablar, isFalse);
      },
    );

    test('un joven de 16 no se puede colocar aunque cumpla lo demás', () async {
      final motor = await _motor();
      motor.estado!.semana = 1;
      final joven = await _reclutarAcademia(
        motor,
        motor.candidatosAcademia.first,
      );
      _prepararParaColocar(joven);
      joven.edad = 16;

      expect(cumpleRequisitosColocacion(joven), isFalse);
      final motivos = motivosParaColocar(motor.estado!, joven);
      expect(motivos.any((m) => m.contains('17')), isTrue);
      final resultado = await motor.colocarJovenAcademia(
        joven,
        motor.equiposParaColocar(joven).first,
      );
      expect(resultado.ok, isFalse);
      expect(joven.enAcademia, isTrue);
    });

    test('exige 4 semanas y habilidad 50', () async {
      final motor = await _motor();
      motor.estado!.semana = 1;
      final joven = await _reclutarAcademia(
        motor,
        motor.candidatosAcademia.first,
      );
      _prepararParaColocar(joven);
      joven.semanasEnAcademia = 3;
      expect(cumpleRequisitosColocacion(joven), isFalse);
      joven.semanasEnAcademia = 4;
      joven.habilidad = 49;
      expect(cumpleRequisitosColocacion(joven), isFalse);
      joven.habilidad = 50;
      expect(cumpleRequisitosColocacion(joven), isTrue);
    });

    test('solo se coloca dentro de una ventana de fichajes', () async {
      final motor = await _motor();
      final joven = await _reclutarAcademia(
        motor,
        motor.candidatosAcademia.first,
      );
      _prepararParaColocar(joven);

      motor.estado!.semana = 5;
      expect(ventanaDeColocacionAbierta(motor.estado!), isFalse);
      expect(
        motivosParaColocar(
          motor.estado!,
          joven,
        ).any((m) => m.toLowerCase().contains('mercado')),
        isTrue,
      );
      final cerrado = await motor.colocarJovenAcademia(
        joven,
        motor.equiposParaColocar(joven).first,
      );
      expect(cerrado.ok, isFalse);

      motor.estado!.semana = 23;
      expect(ventanaDeColocacionAbierta(motor.estado!), isTrue);
      final abierto = await motor.colocarJovenAcademia(
        joven,
        motor.equiposParaColocar(joven).first,
      );
      expect(abierto.ok, isTrue);
    });

    test('al cambiar de temporada se destapan los candidatos viejos', () async {
      final motor = await _motor();
      final viejo = motor.candidatosAcademia.first;
      expect(viejo.candidatoAcademia, isTrue);

      motor.estado!.semana = 52;
      await motor.avanzarSemana();

      expect(viejo.candidatoAcademia, isFalse);
      expect(motor.candidatosAcademia, hasLength(8));
      expect(motor.jugadores.any((j) => j.id == viejo.id), isTrue);
    });
  });

  group('aislamiento', () {
    test('no recibe ofertas de traspaso ni se puede ofrecer', () async {
      final motor = await _motor();
      final joven = await _reclutarAcademia(
        motor,
        motor.candidatosAcademia.first,
      );
      final equipo = motor.equiposDeJuego(joven.juego).first;
      final resultado = await motor.ofrecer(
        jugador: joven,
        equipo: equipo,
        precioPedido: joven.valorMercado,
      );
      expect(resultado.respuesta, RespuestaEquipo.rechaza);
      expect(resultado.mensaje.toLowerCase(), contains('academia'));
    });

    test('no renuncia ni lo roba un rival', () async {
      final motor = await _motor(conRivales: true);
      final joven = await _reclutarAcademia(
        motor,
        motor.candidatosAcademia.first,
      );
      joven.satisfaccion = 0;
      joven.semanasEnfriamientoAgente = 0;

      final semana = sat.procesarSemanaRepresentado(
        estado: motor.estado!,
        jugador: joven,
        rnd: Random(1),
      );
      expect(semana.renuncio, isFalse);
      expect(joven.representadoPorMi, isTrue);

      final rnd = Random(2);
      for (var i = 0; i < 40; i++) {
        rivales.ejecutarSemanaRivales(estado: motor.estado!, rnd: rnd);
      }
      expect(joven.representadoPorMi, isTrue);
      expect(joven.agenteId, 'yo');
    });

    test('los rivales y la IA nunca lo consideran', () async {
      final motor = await _motor(conRivales: true);
      final joven = await _reclutarAcademia(
        motor,
        motor.candidatosAcademia.first,
      );
      final candidato = motor.candidatosAcademia.first;
      final equipo = motor
          .equiposDeJuego(joven.juego)
          .where((e) => e.division == 2)
          .first;

      final mapaJuegoRol = agruparPorJuegoYRol(motor.jugadores);
      for (final objetivo in [joven, candidato]) {
        final lista = candidatosPara(
          equipo: equipo,
          porJuegoRol: mapaJuegoRol,
          indiceEquipos: motor.indices.equipos,
          rol: objetivo.rol,
          umbralHabilidad: 1,
          temporadaActual: motor.temporada,
        );
        expect(lista.any((j) => j.id == objetivo.id), isFalse);
      }

      final antes = {
        for (final j in [joven, candidato]) j.id: (j.equipoId, j.agenteId),
      };
      ficharJovenesDeSegunda(
        estado: motor.estado!,
        rnd: Random(3),
        probabilidad: 1,
      );
      for (final j in [joven, candidato]) {
        expect((j.equipoId, j.agenteId), antes[j.id]);
      }
    });

    test('el mantenimiento no borra candidatos ni académicos', () async {
      final motor = await _motor();
      final candidato = motor.candidatosAcademia.first;
      final joven = await _reclutarAcademia(motor, motor.candidatosAcademia[1]);

      limpiarDatosAntiguos(motor.estado!, limiteLibres: 0);
      expect(motor.jugadores.any((j) => j.id == candidato.id), isTrue);
      expect(motor.jugadores.any((j) => j.id == joven.id), isTrue);
      expect(candidato.candidatoAcademia, isTrue);
      expect(joven.enAcademia, isTrue);
    });

    test('ningún evento de jugador elige a un joven de la academia', () async {
      final motor = await _motor();
      final joven = await _reclutarAcademia(
        motor,
        motor.candidatosAcademia.first,
      );
      motor.estado!.frecuenciaEventos = 'alta';
      final rnd = Random(5);
      for (var i = 0; i < 30; i++) {
        final resultado = generarEventosSemana(
          estado: motor.estado!,
          indiceJugadores: motor.indices.jugadores,
          indiceEquipos: motor.indices.equipos,
          rnd: rnd,
          nuevoIdJugador: motor.nuevoId,
        );
        for (final evento in resultado.eventos) {
          expect(evento.jugadorId, isNot(joven.id));
        }
      }

      // La condición del evento de fuga tampoco lo considera.
      final fuga = catalogoEventos.firstWhere(
        (e) => e.id == 'fuga_informacion',
      );
      final contexto = ContextoEventos(
        estado: motor.estado!,
        indiceJugadores: motor.indices.jugadores,
        indiceEquipos: motor.indices.equipos,
        rnd: Random(6),
        nuevoIdJugador: motor.nuevoId,
      );
      motor.estado!.semana = 1;
      expect(fuga.condicion?.call(contexto, null), isFalse);
    });
  });
}

/// Generador controlado que devuelve siempre el mismo valor en `nextDouble`.
///
/// Se usa para probar probabilidades sin depender de una semilla concreta.
class _DadoFijo implements Random {
  _DadoFijo(this.valor);

  final double valor;

  @override
  bool nextBool() => valor < 0.5;

  @override
  double nextDouble() => valor;

  @override
  int nextInt(int max) => 0;
}
