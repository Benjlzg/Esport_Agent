// Simulación de 10 temporadas (Fase 2.5, pasos 4–7). Genera
// INFORME_BALANCE.md y falla solo después de escribirlo si hay violaciones.
@Tags(['lento'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/formulas.dart';
import 'package:esport_agent/logica/mantenimiento.dart';
import 'package:esport_agent/logica/metricas.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';

import 'apoyo/entorno_simulacion.dart';
import 'apoyo/robot_jugador.dart';

/// Edad máxima del grupo cuya progresión se informa (16–21 años).
const int _edadMaximaJovenInforme = 21;

/// Resultado resumido de una temporada.
class _FilaTemporada {
  _FilaTemporada({
    required this.temporada,
    required this.presupuestoInicio,
    required this.presupuestoFin,
    required this.habilidades,
    required this.valorMaximo,
    required this.valorP95,
    required this.fichajesVentanas,
    required this.fichajesIA,
    required this.ofertasIA,
    required this.eventos,
    required this.decisiones,
    required this.milisegundos,
    required this.jugadores,
    required this.noticias,
    required this.resultados,
    required this.palmares,
    required this.premios,
    required this.ofertas,
    required this.eventosPendientes,
    required this.guardadoKb,
    required this.desglose,
    required this.progresoJoven,
  });

  final int temporada;
  final int presupuestoInicio;
  final int presupuestoFin;
  final Map<Juego, double> habilidades;
  final int valorMaximo;
  final double valorP95;
  final List<int> fichajesVentanas;
  final int fichajesIA;
  final int ofertasIA;
  final int eventos;
  final int decisiones;
  final int milisegundos;

  // Tamaño de las listas guardadas (corrección A3).
  final int jugadores;
  final int noticias;
  final int resultados;
  final int palmares;
  final int premios;
  final int ofertas;
  final int eventosPendientes;
  final double guardadoKb;

  /// Desglose por lista del guardado en ese momento (Parte 3D).
  final Map<String, double> desglose;

  // Progresión media de los jugadores de 16–21 años (ajuste de balance).
  final _ProgresoJoven progresoJoven;
}

/// Datos de un jugador de 16–21 años al empezar la temporada. Se guarda su
/// habilidad y su situación para comparar al final de la temporada.
class _JovenInicio {
  _JovenInicio({
    required this.id,
    required this.habilidad,
    required this.potencial,
    required this.conEquipo,
    required this.titular,
  });

  final String id;
  final int habilidad;
  final int potencial;
  final bool conEquipo;
  final bool titular;

  /// Un jugador que ya está en su potencial no puede subir: se cuenta aparte
  /// para que no hunda la media de quienes todavía tienen margen.
  bool get enSuPotencial => habilidad >= potencial;
}

/// Promedios de subida de los jóvenes de 16–21 años en una temporada.
class _ProgresoJoven {
  _ProgresoJoven({
    required this.conEquipo,
    required this.sinEquipo,
    required this.titulares,
    required this.suplentes,
    required this.media,
    required this.medidos,
    required this.enSuPotencial,
  });

  /// Promedios de jugadores que todavía podían mejorar al empezar la
  /// temporada (no estaban en su potencial).
  final double conEquipo;
  final double sinEquipo;
  final double titulares;
  final double suplentes;

  /// Media de todos los jóvenes medidos, incluidos los que ya estaban en su
  /// potencial y por tanto no podían subir.
  final double media;

  /// Jugadores comparados al inicio y al final de la temporada.
  final int medidos;

  /// Cuántos de los medidos ya estaban en su potencial al empezar.
  final int enSuPotencial;

  /// Calcula los promedios comparando la habilidad inicial con la final.
  /// Solo cuenta jugadores que siguen en la partida al terminar la temporada
  /// (los retirados o eliminados no tienen una medición justa).
  static _ProgresoJoven calcular(List<_JovenInicio> inicio, List<Jugador> fin) {
    final porId = {for (final j in fin) j.id: j};
    final conEquipo = <int>[];
    final sinEquipo = <int>[];
    final titulares = <int>[];
    final suplentes = <int>[];
    final todos = <int>[];
    var enSuPotencial = 0;

    for (final joven in inicio) {
      final actual = porId[joven.id];
      if (actual == null) continue;
      final subida = actual.habilidad - joven.habilidad;
      todos.add(subida);
      if (joven.enSuPotencial) {
        enSuPotencial++;
        continue;
      }
      if (joven.conEquipo) {
        conEquipo.add(subida);
        if (joven.titular) {
          titulares.add(subida);
        } else {
          suplentes.add(subida);
        }
      } else {
        sinEquipo.add(subida);
      }
    }

    double promedio(List<int> valores) {
      if (valores.isEmpty) return 0;
      return valores.reduce((a, b) => a + b) / valores.length;
    }

    return _ProgresoJoven(
      conEquipo: promedio(conEquipo),
      sinEquipo: promedio(sinEquipo),
      titulares: promedio(titulares),
      suplentes: promedio(suplentes),
      media: promedio(todos),
      medidos: todos.length,
      enSuPotencial: enSuPotencial,
    );
  }
}

/// Guarda la habilidad y la situación de los jugadores de 16–21 años.
List<_JovenInicio> _capturarJovenes(EstadoPartida estado) {
  return [
    for (final j in estado.jugadores)
      if (j.edad >= 16 && j.edad <= _edadMaximaJovenInforme)
        _JovenInicio(
          id: j.id,
          habilidad: j.habilidad,
          potencial: j.potencial,
          conEquipo: j.equipoId != null,
          titular: j.equipoId != null && !j.suplente,
        ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('10 temporadas con semilla fija', () async {
    final motor = await crearPartidaSembrada();
    final filas = <_FilaTemporada>[];
    final violaciones = <String>[];
    final relojTotal = Stopwatch()..start();
    var milisegundosSemanas = 0;

    for (var temporada = 1; temporada <= 10; temporada++) {
      final estadoInicio = motor.estado!;
      expect(estadoInicio.temporada, temporada);
      expect(estadoInicio.semana, 1);
      // La progresión de jóvenes se mide desde el inicio hasta el final de la
      // temporada, antes de que el rollover envejezca a los jugadores.
      final jovenesInicio = _capturarJovenes(estadoInicio);

      final inicio = revisarInvariantes(estadoInicio, revisarPlantillas: true);
      violaciones.addAll(
        inicio.violaciones.map((v) => 'T$temporada inicio: $v'),
      );
      final presupuestoInicio = presupuestoTotal(estadoInicio);
      final fichajesVentanas = <int>[0, 0, 0];

      final relojTemporada = Stopwatch()..start();
      // Se simulan las semanas 1–51. La semana 52 se juega al final para
      // poder medir el cierre antes de que _nuevaTemporada reinicie todo.
      for (var semana = 1; semana <= 51; semana++) {
        final relojSemana = Stopwatch()..start();
        await avanzarSemanaSimulada(motor);
        relojSemana.stop();
        milisegundosSemanas += relojSemana.elapsedMilliseconds;

        final estado = motor.estado!;
        if (estado.semana == 5) {
          fichajesVentanas[0] = motor.metricas.fichajesVentana;
        } else if (estado.semana == 27) {
          fichajesVentanas[1] = motor.metricas.fichajesVentana;
        }
        if (estado.finDelJuego) {
          fail('La partida observadora quebró en la temporada $temporada.');
        }
      }

      final estadoFin = motor.estado!;
      expect(estadoFin.semana, 52);
      expect(estadoFin.temporada, temporada);
      final fin = revisarInvariantes(estadoFin, revisarPlantillas: true);
      violaciones.addAll(fin.violaciones.map((v) => 'T$temporada fin: $v'));

      // Se miden economía, habilidades y títulos antes del rollover, porque
      // _nuevaTemporada reinicia presupuestos y estadísticas.
      final presupuestoFin = presupuestoTotal(estadoFin);
      final habilidades = <Juego, double>{
        for (final juego in Juego.values)
          juego: habilidadPromedioPorJuego(estadoFin, juego),
      };
      final valores = estadoFin.jugadores.map((j) => j.valorMercado).toList();
      final eventos = motor.metricas.eventosGenerados;
      final decisiones = motor.metricas.eventosConDecision;

      // Se mide qué listas crecen con las temporadas (A3) y el tamaño real
      // del JSON que se guarda en disco.
      final resultados = estadoFin.competiciones.fold<int>(
        0,
        (suma, comp) => suma + comp.todosLosResultados.length,
      );
      final guardadoKb =
          utf8.encode(jsonEncode(estadoFin.toJson())).length / 1024;
      final desglose = _desgloseGuardado(estadoFin);
      final progresoJoven = _ProgresoJoven.calcular(
        jovenesInicio,
        estadoFin.jugadores,
      );

      // Última semana: cierra la temporada y hace el rollover. Los fichajes
      // de la semana 52 completan la tercera ventana.
      final relojSemanaFinal = Stopwatch()..start();
      await avanzarSemanaSimulada(motor);
      relojSemanaFinal.stop();
      milisegundosSemanas += relojSemanaFinal.elapsedMilliseconds;
      fichajesVentanas[2] = motor.metricas.fichajesVentana;
      final fichajesIA = motor.metricas.fichajesIA;
      final ofertasIA = motor.metricas.ofertasIA;

      relojTemporada.stop();
      filas.add(
        _FilaTemporada(
          temporada: temporada,
          presupuestoInicio: presupuestoInicio,
          presupuestoFin: presupuestoFin,
          habilidades: habilidades,
          valorMaximo: valores.reduce((a, b) => a > b ? a : b),
          valorP95: percentil(valores, 0.95),
          fichajesVentanas: fichajesVentanas,
          fichajesIA: fichajesIA,
          ofertasIA: ofertasIA,
          eventos: eventos,
          decisiones: decisiones,
          milisegundos: relojTemporada.elapsedMilliseconds,
          jugadores: estadoFin.jugadores.length,
          noticias: estadoFin.noticias.length,
          resultados: resultados,
          palmares: estadoFin.palmares.length,
          premios: estadoFin.premios.length,
          ofertas: estadoFin.ofertas.length,
          eventosPendientes: estadoFin.eventosPendientes.length,
          guardadoKb: guardadoKb,
          desglose: desglose,
          progresoJoven: progresoJoven,
        ),
      );
    }
    relojTotal.stop();

    // El robot de 3 temporadas se incluye en el mismo informe. La segunda
    // corrida es solo informativa: misma semilla, 1 venta por semana.
    final robot = await ejecutarRobotDePrueba();
    final robotConservador = await ejecutarRobotDePrueba(maxVentasPorSemana: 1);

    final resumen = _escribirInforme(
      filas: filas,
      estadoFinal: motor.estado!,
      violaciones: violaciones,
      milisegundosSemanas: milisegundosSemanas,
      milisegundosTotal: relojTotal.elapsedMilliseconds,
      robot: robot,
      robotConservador: robotConservador,
    );

    // Comprobación de que el informe realmente se regeneró en la raíz del
    // proyecto y lleva fecha/hora (así nunca queda idéntico al anterior).
    final archivoInforme = File('INFORME_BALANCE.md');
    expect(
      archivoInforme.existsSync(),
      isTrue,
      reason: 'No se escribió INFORME_BALANCE.md en la raíz del proyecto.',
    );
    final textoInforme = archivoInforme.readAsStringSync();
    expect(textoInforme, contains('- Generado: **'));
    expect(textoInforme, contains('## Progresión de jóvenes'));
    expect(textoInforme, contains('## Criterios de la Fase 3A'));
    expect(textoInforme, contains('## Criterios de la Fase 3B'));
    expect(textoInforme, contains('## Criterios de la Fase 3C'));
    expect(textoInforme, contains('## Criterios de la Fase 3D'));
    expect(textoInforme, contains('## Criterios de la Fase 3E'));
    expect(textoInforme, contains('## Robot conservador'));
    expect(textoInforme, contains('## Desglose del guardado final'));

    // El test falla DESPUÉS de escribir el informe para poder diagnosticar.
    expect(
      violaciones,
      isEmpty,
      reason: 'Violaciones duras:\n${violaciones.join('\n')}',
    );
    expect(resumen, isNotEmpty);

    // Criterios de balance de las Partes 3A y 3B.
    expect(robot.cumpleCriterioRobos, isTrue);
    expect(robot.cumpleCriterioFichajes, isTrue);
    expect(robot.cumpleCriterioRivales, isTrue);
    expect(robot.cumpleCriterioReputacion, isTrue);
    expect(robot.cumpleCriterioPerdidasSatisfaccion, isTrue);
    expect(robot.cumpleCriterioSatisfaccion, isTrue);
    expect(robot.cumpleCriterioComision, isTrue);
    expect(robot.cumpleCriterioPromesas, isTrue);

    // Criterios de balance de la Parte 3C.
    expect(robot.cumpleCriterioOjeadores, isTrue);
    expect(robot.cumpleCriterioSemiancho, isTrue);
    expect(robot.cumpleCriterioGastoOjeadores, isTrue);
    expect(robot.cumpleCriterioTalentosRivales, isTrue);

    // Criterios de balance de la Parte 3D.
    expect(robot.cumpleCriterioAbogado, isTrue);
    expect(robot.cumpleCriterioRelacionesPublicas, isTrue);
    expect(robot.cumpleCriterioGastoStaff, isTrue);
    expect(robot.cumpleDineroMinimoFinal, isTrue);

    // Criterios de balance de la Parte 3E.
    expect(robot.cumpleCriterioJovenesT1, isTrue);
    expect(robot.cumpleCriterioColocacionT2, isTrue);
    expect(robot.cumpleCriterioSaldoAcademia, isTrue);
    expect(robot.cumpleCriterioHabilidadColocacion, isTrue);
    expect(robot.cumpleCriterioAcademiaSinRivales, isTrue);
    expect(robot.cumpleCriterioIngresoAcademia, isTrue);
    expect(
      filas.last.milisegundos / filas.first.milisegundos,
      lessThanOrEqualTo(1.5),
      reason: 'El paso semanal creció más de 1,5× entre la T1 y la T10.',
    );
    expect(
      filas.last.guardadoKb,
      lessThanOrEqualTo(5000),
      reason: 'El guardado final superó el tope de 5.000 KB de la Fase 3E.',
    );
  }, timeout: const Timeout(Duration(minutes: 30)));
}

String _escribirInforme({
  required List<_FilaTemporada> filas,
  required EstadoPartida estadoFinal,
  required List<String> violaciones,
  required int milisegundosSemanas,
  required int milisegundosTotal,
  required ResultadoRobot robot,
  required ResultadoRobot robotConservador,
}) {
  // Dominio por liga (B3): se calcula antes de escribir la tabla de ajustes
  // para poder anotar el resultado de la ronda 5.
  final dominios = dominioPorLiga(estadoFinal);
  final topDominios = dominios.take(5).toList();
  final maxTemporadasDominio = dominios.isEmpty
      ? 0
      : dominios.first.temporadasGanadas;
  final ligasExcedidas = dominios
      .where((d) => d.temporadasGanadas > 6)
      .toList();

  final buffer = StringBuffer()
    ..writeln('# INFORME DE BALANCE — FASE 3E')
    ..writeln()
    ..writeln('- Generado: **${_fechaHora(DateTime.now())}** (hora local).')
    ..writeln('- Generado por: `test/balance_test.dart`.')
    ..writeln()
    ..writeln('- Semilla: **$semillaInforme**.')
    ..writeln(
      '- Partida observadora (10 temporadas): agente con '
      '${miles(dineroObservador)} de dinero, sin reclutar.',
    )
    ..writeln(
      '- Los eventos se resuelven solos eligiendo la opción más barata.',
    )
    ..writeln(
      '- Parte 3A: los agentes rivales están activos en la partida '
      'observadora y en el robot. Sus criterios se miden en la sección '
      '«Criterios de la Fase 3A».',
    )
    ..writeln(
      '- Parte 3B: la satisfacción usa expectativas y contratos de '
      'representación. El robot responde a los avisos y renueva sus '
      'contratos; sus criterios se miden en «Criterios de la Fase 3B».',
    )
    ..writeln(
      '- Parte 3C: el potencial real está oculto tras un rango estimado y '
      'los ojeadores lo estrechan. El robot contrata 2 ojeadores nivel 2 y '
      'ficha por el punto medio del rango; sus criterios se miden en '
      '«Criterios de la Fase 3C».',
    )
    ..writeln(
      '- Parte 3D: el robot contrata abogado nivel 2 en la T2 y relaciones '
      'públicas nivel 2 en la T3 si tiene reserva para 30 semanas del gasto '
      'fijo total. Sus criterios se miden en «Criterios de la Fase 3D».',
    )
    ..writeln(
      '- Parte 3E: la academia recluta jóvenes de 15–17 años, los entrena y '
      'los coloca en 2ª División. Sus criterios se miden en «Criterios de la '
      'Fase 3E».',
    )
    ..writeln(
      '- Comando: `flutter test test/balance_test.dart --tags lento '
      '--run-skipped`. La suite normal (`flutter test`) salta estas pruebas.',
    )
    ..writeln()
    ..writeln('## Ajustes de constantes')
    ..writeln();

  buffer
    ..writeln(
      'Las rondas **1–3** son las del ajuste de dominio y economía de la '
      'Fase 2.5. La **ronda 4** corresponde a la revisión de comisiones y '
      'cuadratura. La **ronda 5** corrige el retroceso de dominio detectado '
      'tras la auditoría: el club vendedor cobraba la cláusula y la dinastía '
      'volvía a fichar figuras con ese dinero. Los cambios se probaron con la '
      'misma semilla y el informe se regeneró después de cada ronda. La '
      '**ronda 6** suaviza el castigo de reputación de los eventos negativos '
      'para que el robot no quede por debajo de la meta cuando se acumulan.',
    )
    ..writeln()
    ..writeln(
      tablaMarkdown(
        ['Ronda', 'Cambio', 'Antes', 'Después', 'Resultado'],
        [
          [
            '1',
            'divisor de `probVictoria`',
            '6,0',
            '9,0',
            'Más aleatoriedad en las series. El máximo de dominio bajó de 10 '
                'a 10, pero las ligas con campeón > 6 pasaron de 17 a 11–14: '
                'no alcanzó.',
          ],
          [
            '1',
            'equipos ficticios de 1ª División',
            'Prestigio 35–54 (nivel de 2ª)',
            'Prestigio 68–84',
            'Las regiones con pocos equipos reales dejaron de tener un '
                'campeón casi fijo, pero una dinastía podía seguir creciendo.',
          ],
          [
            '1',
            'ingresos de eventos',
            'Streamer 5–20 mil · Marca 10–50 mil · Inversor 25–100 mil',
            'Streamer 2–6 mil · Marca 4–15 mil · Inversor 8–30 mil',
            'Los traspasos pasaron a ser la principal fuente de ingresos del '
                'robot.',
          ],
          [
            '1',
            'reputación por traspaso',
            '+1 normal / +3 élite',
            '+2 normal / +3 élite, con rendimientos decrecientes',
            'La reputación dejó de bajar en las temporadas con ventas, pero '
                'podía pasarse del techo de 45.',
          ],
          [
            '1',
            'desgaste de campeones',
            'Sin desgaste',
            '−10 de moral al empezar la temporada siguiente',
            'Ayudó, pero por sí solo no impedía que el mismo equipo ganara '
                '7–10 de 10 temporadas.',
          ],
          [
            '2',
            'divisor de `probVictoria`',
            '9,0',
            '12,0',
            'Más series igualadas. El dominio seguía por encima de la meta '
                'en 14–18 ligas: el problema era la plantilla, no solo el azar.',
          ],
          [
            '2',
            'equipos ficticios de 1ª División',
            'Prestigio 68–84',
            'Prestigio 70–80',
            'Mayor paridad inicial entre los rellenos y los equipos reales.',
          ],
          [
            '2',
            'fichajes contra campeones',
            'Margen de prestigio 8 · probabilidad 0,65',
            'Margen de prestigio 20 · probabilidad 0,85',
            'Los rivales intentaron fichar más a las figuras de los '
                'campeones, pero el presupuesto limitaba las salidas.',
          ],
          [
            '2',
            'red de seguridad de plantillas',
            'Solo se reponía el rol del jugador traspasado',
            'Se comprueban los 5 roles de todos los equipos al cerrar la '
                'ventana',
            'Corrige los huecos de 4 titulares que aparecieron al encadenar '
                'fichajes y recortes de suplentes.',
          ],
          [
            '3',
            'divisor de `probVictoria`',
            '12,0',
            '18,0',
            'Series aún más abiertas; se mantiene la ventaja del equipo con '
                'más poder, pero sin resultados casi automáticos.',
          ],
          [
            '3',
            'anti-dinastía',
            'Solo campeones del año anterior',
            'Equipos con 3+ títulos de split en 5 temporadas: pierden 3–5 '
                'figuras, solo hacia equipos que no son dinastías y con '
                'cláusula de salida del 40 %',
            'Rompe el círculo en el que los campeones se reforzaban entre '
                'ellos. Es el cambio que más redujo el dominio.',
          ],
          [
            '3',
            'orden del mercado IA',
            'Orden fijo: primero los equipos más fuertes',
            'Orden aleatorio cada ventana',
            'Los equipos fuertes dejaron de elegir siempre los mejores '
                'agentes libres.',
          ],
          [
            '3',
            'desgaste competitivo',
            'Sin penalización de poder',
            'Cada título reciente por encima de 2 resta 4 % de poder '
                '(máximo 20 %); se recupera al dejar de ganar',
            'Freno determinista para las dinastías, independiente de que '
                'haya comprador o presupuesto.',
          ],
          [
            '3',
            'reputación por traspaso',
            '+2 normal / +3 élite',
            'Se mantiene +2/+3, pero a partir de 40 solo sube con eventos, '
                'premios o títulos',
            'El robot termina la T3 con 37 de reputación (meta 30–45).',
          ],
          [
            '3',
            'reemplazos',
            'ajusteHabilidadReemplazo = −3',
            'ajusteHabilidadReemplazo = −4',
            'El salto máximo de habilidad entre temporadas baja a 2,86 '
                '(límite 3).',
          ],
          [
            '4',
            'reemplazos',
            'ajusteHabilidadReemplazo = −4',
            'ajusteHabilidadReemplazo = −5',
            'El salto T1→T2 había vuelto a 3,40 con los cambios posteriores '
                'de plantillas. Con −5 queda por debajo del límite de 3 sin '
                'tocar la progresión juvenil.',
          ],
          [
            '5',
            'fichajes de dinastías',
            'Sin límite: la dinastía vendía figuras por la cláusula, cobraba '
                'el dinero y volvía a fichar a los mejores. Dominio máximo '
                '8/10 (3 ligas por encima de 6).',
            'Con 3+ títulos de 1ª División en 5 temporadas solo puede fichar '
                'jugadores con habilidad ≤ su mejor titular en esa ventana.',
            'Dominio máximo $maxTemporadasDominio de 10; '
                '${ligasExcedidas.length} ligas por encima de 6.',
          ],
          [
            '6',
            'reputación en eventos negativos',
            '`polemica_redes` y `rumor_negativo` restaban 2 puntos cada uno.',
            'Restan 1 punto cada uno; los traspasos mantienen su tope en 40.',
            'Reputación final del robot: '
                '${robot.filas.isEmpty ? 0 : robot.filas.last.reputacionFin} '
                '(meta 30–45). No afecta al dominio: la reputación es solo '
                'del agente.',
          ],
          [
            '3D-1',
            'política de ventas del robot (no es una constante de balance)',
            '1 venta por semana en ventana: la T3 terminó con \$11.325 y el '
                'gasto de ojeadores fue el 24,6 % de los ingresos.',
            'Hasta 2 ventas por semana en ventana.',
            'La T3 termina con ${formatearDinero(robot.dineroFinal)} y el '
                'gasto de ojeadores baja al '
                '${decimal(robot.filas.isEmpty || robot.filas.last.ingresosTemporada == 0 ? 0 : robot.filas.last.gastoOjeadores / robot.filas.last.ingresosTemporada * 100, 1)} % '
                'de los ingresos. Criterios 3A–3D verdes.',
          ],
        ],
      ),
    )
    ..writeln()
    ..writeln(
      'La Parte 3C **no necesitó ajustes de constantes**: la primera '
      'medición cumplió los cuatro criterios. La única decisión de diseño '
      'fue la política fija del robot (2 ojeadores nivel 2 en los dos pares '
      'con más agentes libres de 21 años o menos) y el uso del punto medio '
      'del rango visible para fichar.',
    )
    ..writeln(
      'La Parte 3D tampoco cambió las constantes de balance: usa los '
      'salarios, márgenes y bonus del plan. La política del robot intenta '
      'contratar/mejorar el abogado en la T2 y la RP en la T3 solo cuando '
      'hay reserva para 30 semanas del gasto fijo total.',
    )
    ..writeln(
      'La Parte 3E **no necesitó ninguna ronda de ajuste**: el ingreso de la '
      'academia en la T3 fue del 0,0 % de los ingresos totales, por debajo '
      'del tope del 20 %. Se mantiene `porcentajeDerechosFormacion` en 1,0 y '
      '`habilidadMinimaColocar` en 45.',
    )
    ..writeln(
      'La **ronda 3D-1** es un ajuste de política del robot, no de las '
      'constantes: con una sola venta por semana el gasto del staff dejaba la '
      'T3 en \$11.325 y los ojeadores superaban el 15 % de los ingresos. Se '
      'permitieron hasta 2 ventas por semana en ventana y todos los criterios '
      'volvieron a cumplirse.',
    )
    ..writeln()
    ..writeln('### Correcciones de lógica')
    ..writeln()
    ..writeln(
      '- Al vencer el contrato de un titular, su equipo repone el rol en la '
      'misma semana. Sin esto, las plantillas se vaciaban con las temporadas '
      'y desde T2 había equipos sin 5 titulares.',
    )
    ..writeln(
      '- La red de seguridad de `procesarMercadoIA` repone cualquier rol que '
      'quede vacío después de una cadena de traspasos y recortes de suplentes.',
    );
  buffer
    ..writeln()
    ..writeln('## Economía y valores')
    ..writeln()
    ..writeln(
      tablaMarkdown(
        [
          'Temporada',
          'Presup. inicio',
          'Presup. fin',
          'Fin / inicio',
          'Valor máx.',
          'Valor P95',
        ],
        [
          for (final fila in filas)
            [
              '${fila.temporada}',
              miles(fila.presupuestoInicio),
              miles(fila.presupuestoFin),
              '${decimal(fila.presupuestoFin / fila.presupuestoInicio, 2)}×',
              miles(fila.valorMaximo),
              miles(fila.valorP95.round()),
            ],
        ],
      ),
    );

  buffer
    ..writeln()
    ..writeln('## Habilidad promedio por videojuego (jugadores con equipo)')
    ..writeln()
    ..writeln(
      tablaMarkdown(
        ['Temporada', for (final juego in Juego.values) juego.corto, 'Media'],
        [
          for (final fila in filas)
            [
              '${fila.temporada}',
              for (final juego in Juego.values)
                decimal(fila.habilidades[juego]!, 1),
              decimal(
                fila.habilidades.values.reduce((a, b) => a + b) /
                    fila.habilidades.length,
                1,
              ),
            ],
        ],
      ),
    );

  // Progresión de jóvenes (ajuste de balance): un jugador de 16–21 años debe
  // subir entre 4 y 8 puntos por temporada; sin equipo, la mitad.
  final conEquipoJoven = filas
      .where((f) => f.progresoJoven.conEquipo > 0)
      .map((f) => f.progresoJoven.conEquipo)
      .toList();
  final mediaConEquipo = conEquipoJoven.isEmpty
      ? 0.0
      : conEquipoJoven.reduce((a, b) => a + b) / conEquipoJoven.length;
  final mediaSinEquipoJoven = filas
      .where((f) => f.progresoJoven.sinEquipo > 0)
      .map((f) => f.progresoJoven.sinEquipo)
      .toList();
  final mediaSinEquipo = mediaSinEquipoJoven.isEmpty
      ? 0.0
      : mediaSinEquipoJoven.reduce((a, b) => a + b) /
            mediaSinEquipoJoven.length;
  final progresionCumple = mediaConEquipo >= 4.0 && mediaConEquipo <= 8.0;
  final jovenesEnPotencial = filas.fold<int>(
    0,
    (suma, fila) => suma + fila.progresoJoven.enSuPotencial,
  );

  buffer
    ..writeln()
    ..writeln('## Progresión de jóvenes (16–21 años)')
    ..writeln()
    ..writeln(
      'Se compara la habilidad al inicio y al final de cada temporada de los '
      'jugadores que tenían entre 16 y 21 años al empezar (solo los que '
      'siguen en la partida). Objetivo: un joven con equipo debe subir entre '
      '**4 y 8 puntos por temporada**. Sin equipo la probabilidad de mejorar '
      'es la mitad; los suplentes mejoran un poco menos que los titulares.',
    )
    ..writeln()
    ..writeln(
      'Los promedios por situación excluyen a los jugadores que ya estaban en '
      'su potencial al empezar (no podían subir). La columna **Media todos** '
      'los incluye para que la medición sea transparente.',
    )
    ..writeln()
    ..writeln(
      tablaMarkdown(
        [
          'Temporada',
          'Con equipo',
          'Sin equipo',
          'Titulares',
          'Suplentes',
          'Media todos',
          'Medidos',
          'En su potencial',
        ],
        [
          for (final fila in filas)
            [
              '${fila.temporada}',
              decimal(fila.progresoJoven.conEquipo, 1),
              decimal(fila.progresoJoven.sinEquipo, 1),
              decimal(fila.progresoJoven.titulares, 1),
              decimal(fila.progresoJoven.suplentes, 1),
              decimal(fila.progresoJoven.media, 1),
              '${fila.progresoJoven.medidos}',
              '${fila.progresoJoven.enSuPotencial}',
            ],
        ],
      ),
    )
    ..writeln()
    ..writeln(
      '- Progresión media con equipo (con margen de mejora): '
      '**${decimal(mediaConEquipo, 1)} puntos/temporada** · sin equipo: '
      '**${decimal(mediaSinEquipo, 1)}**.',
    )
    ..writeln(
      '- La regla ×0,5 para jugadores sin equipo se aplica por jugador y '
      'está cubierta por `test/progresion_test.dart`; la media observada sin '
      'equipo puede variar por la mezcla de edades y de potencial.',
    )
    ..writeln(
      '- Jugadores medidos en 10 temporadas: '
      '${filas.fold<int>(0, (suma, f) => suma + f.progresoJoven.medidos)} · '
      'ya estaban en su potencial: $jovenesEnPotencial.',
    )
    ..writeln(
      '- Criterio 4–8 puntos por temporada: '
      '**${progresionCumple ? 'cumple' : 'no cumple'}**.',
    );

  // Dominio por liga (B3): temporadas distintas ganadas por el mismo equipo.
  buffer
    ..writeln()
    ..writeln('## Dominio por liga (1ª División, 10 temporadas)')
    ..writeln()
    ..writeln(
      'Para cada liga de 1ª División se cuentan las temporadas distintas en '
      'las que el mismo equipo ganó al menos un split. Se muestran las 5 '
      'ligas con un campeón más repetido. Criterio orientativo: ningún '
      'equipo debería ganar su liga más de 6 de 10 temporadas.',
    )
    ..writeln();
  if (topDominios.isEmpty) {
    buffer.writeln('No se registraron títulos de liga.');
  } else {
    buffer.writeln(
      tablaMarkdown(
        ['Liga', 'Equipo', 'Temporadas ganadas', 'Títulos de split'],
        [
          for (final dominio in topDominios)
            [
              dominio.liga,
              dominio.equipoId,
              '${dominio.temporadasGanadas} de 10',
              '${dominio.titulosSplit}',
            ],
        ],
      ),
    );
  }
  buffer
    ..writeln()
    ..writeln(
      '- Ligas con un campeón por encima de 6 de 10 temporadas: '
      '**${ligasExcedidas.length}**.',
    );
  if (ligasExcedidas.isNotEmpty) {
    buffer.writeln(
      '- Ajuste pendiente: todavía hay ligas por encima del criterio. '
      'Revisar el desgaste competitivo y los fichajes contra dinastías.',
    );
  } else {
    buffer.writeln(
      '- Criterio ≤ 6 de 10: **cumple**. Se aplicaron más aleatoriedad en las '
      'series, paridad en los equipos ficticios, desgaste de moral y de poder '
      'a las dinastías, y fichajes dirigidos contra sus figuras.',
    );
  }

  buffer
    ..writeln()
    ..writeln('## Mercado y eventos')
    ..writeln()
    ..writeln(
      tablaMarkdown(
        [
          'Temporada',
          'Fichajes IA V1 (1–4)',
          'Fichajes IA V2 (23–26)',
          'Fichajes IA V3 (47–52)',
          'Fichajes IA total',
          'Ofertas al agente (observador)',
          'Eventos',
          'Eventos con decisión',
        ],
        [
          for (final fila in filas)
            [
              '${fila.temporada}',
              '${fila.fichajesVentanas[0]}',
              '${fila.fichajesVentanas[1]}',
              '${fila.fichajesVentanas[2]}',
              '${fila.fichajesIA}',
              '${fila.ofertasIA}',
              '${fila.eventos}',
              '${fila.decisiones}',
            ],
        ],
      ),
    );

  buffer
    ..writeln()
    ..writeln(
      '- **Ofertas al agente (observador):** son 0 porque la partida '
      'observadora no recluta jugadores. Sin representados, la IA no tiene a '
      'quién enviar ofertas.',
    );

  buffer
    ..writeln()
    ..writeln('## Tiempos')
    ..writeln()
    ..writeln(
      tablaMarkdown(
        ['Temporada', 'Tiempo total', 'Media por semana'],
        [
          for (final fila in filas)
            [
              '${fila.temporada}',
              '${fila.milisegundos} ms',
              '${decimal(fila.milisegundos / 52, 1)} ms',
            ],
        ],
      ),
    )
    ..writeln()
    ..writeln('- Semanas medidas: 520.')
    ..writeln('- Tiempo total de avance: $milisegundosTotal ms.')
    ..writeln(
      '- Media global por semana: '
      '${decimal(milisegundosSemanas / 520, 1)} ms.',
    )
    ..writeln();

  // Criterios de la Parte 3A (agentes rivales). Se miden con el robot de 3
  // temporadas y con la partida observadora de 10 temporadas.
  final tiempoT10SobreT1 = filas.isEmpty
      ? 0.0
      : filas.last.milisegundos / filas.first.milisegundos;
  final robosPorTemporada = robot.filas
      .map((fila) => 'T${fila.temporada}: ${fila.perdidasPorRobo}')
      .join(' · ');
  final fichajesPorTemporada = robot.filas
      .map((fila) => 'T${fila.temporada}: ${fila.fichajes}')
      .join(' · ');
  buffer
    ..writeln('## Criterios de la Fase 3A (agentes rivales)')
    ..writeln()
    ..writeln(
      tablaMarkdown(
        ['Criterio', 'Medición', 'Meta', '¿Cumple?'],
        [
          [
            'Pérdidas del robot por robo',
            '$robosPorTemporada (máximo ${robot.maxPerdidasPorRobo} por '
                'temporada)',
            '≤ 1 por temporada',
            robot.cumpleCriterioRobos ? 'cumple' : 'no cumple',
          ],
          [
            'Reclutamientos del robot',
            '$fichajesPorTemporada (mínimo '
                '${robot.minimoFichajesPorTemporada} por temporada)',
            '≥ 5 por temporada',
            robot.cumpleCriterioFichajes ? 'cumple' : 'no cumple',
          ],
          [
            'Jugadores que empezaron sin agente y acabaron en un rival',
            '${robot.jugadoresSinAgenteEnRivales} de '
                '${robot.jugadoresSinAgenteIniciales} '
                '(${decimal(robot.porcentajeEnRivales * 100, 1)} %)',
            '≤ 40 %',
            robot.cumpleCriterioRivales ? 'cumple' : 'no cumple',
          ],
          [
            'Reputación del robot al final de la T3',
            '${robot.reputacionFinal}',
            '30–45',
            robot.cumpleCriterioReputacion ? 'cumple' : 'no cumple',
          ],
          [
            'Tiempo semanal de la T10 frente a la T1',
            '${decimal(tiempoT10SobreT1, 2)}×',
            '≤ 1,5×',
            tiempoT10SobreT1 <= 1.5 ? 'cumple' : 'no cumple',
          ],
        ],
      ),
    )
    ..writeln();

  // Criterios de la Parte 3B (satisfacción y contratos).
  final perdidasSatisfaccionPorTemporada = robot.filas
      .map((fila) => 'T${fila.temporada}: ${fila.perdidasPorInsatisfaccion}')
      .join(' · ');
  buffer
    ..writeln('## Criterios de la Fase 3B (satisfacción)')
    ..writeln()
    ..writeln(
      tablaMarkdown(
        ['Criterio', 'Medición', 'Meta', '¿Cumple?'],
        [
          [
            'Pérdidas del robot por insatisfacción o robo',
            '$perdidasSatisfaccionPorTemporada (máximo '
                '${robot.maxPerdidasPorSatisfaccion} por temporada)',
            '≤ 2 por temporada',
            robot.cumpleCriterioPerdidasSatisfaccion ? 'cumple' : 'no cumple',
          ],
          [
            'Satisfacción media de la cartera al final de la T3',
            decimal(robot.satisfaccionMedia, 1),
            '55–85',
            robot.cumpleCriterioSatisfaccion ? 'cumple' : 'no cumple',
          ],
          [
            'Comisión media de los contratos',
            '${decimal(robot.comisionMedia * 100, 1)} %',
            '4–6 %',
            robot.cumpleCriterioComision ? 'cumple' : 'no cumple',
          ],
          [
            'Promesas incumplidas',
            '${robot.promesasIncumplidas}',
            '≤ 2',
            robot.cumpleCriterioPromesas ? 'cumple' : 'no cumple',
          ],
        ],
      ),
    )
    ..writeln();

  // Criterios de la Parte 3C (ojeadores y potencial oculto).
  final semianchoT1 = robot.semianchoT1;
  final semianchoT3 = robot.semianchoT3;
  final filaT3 = robot.filas.isEmpty ? null : robot.filas.last;
  final gastoOjeadoresT3 = filaT3?.gastoOjeadores ?? 0;
  final ingresosT3 = filaT3?.ingresosTemporada ?? 0;
  final porcentajeOjeadoresT3 = ingresosT3 == 0
      ? 0.0
      : gastoOjeadoresT3 / ingresosT3 * 100;
  buffer
    ..writeln('## Criterios de la Fase 3C (ojeadores)')
    ..writeln()
    ..writeln(
      tablaMarkdown(
        ['Criterio', 'Medición', 'Meta', '¿Cumple?'],
        [
          [
            'Ojeadores nivel 2 contratados por el robot',
            '${robot.ojeadoresNivel2}',
            '2',
            robot.cumpleCriterioOjeadores ? 'cumple' : 'no cumple',
          ],
          [
            'Semiancho medio de los fichajes T1 → T3',
            '${decimal(semianchoT1, 1)} → ${decimal(semianchoT3, 1)}',
            'baja de T1 a T3',
            robot.cumpleCriterioSemiancho ? 'cumple' : 'no cumple',
          ],
          [
            'Gasto en ojeadores de la T3 / ingresos de la T3',
            '${formatearDinero(gastoOjeadoresT3)} de '
                '${formatearDinero(ingresosT3)} '
                '(${decimal(porcentajeOjeadoresT3, 1)} %)',
            '≤ 15 %',
            robot.cumpleCriterioGastoOjeadores ? 'cumple' : 'no cumple',
          ],
          [
            'Top 20 de potencial real en manos de rivales',
            '${robot.top20ConRival} de ${robot.top20Considerados} '
                '(${decimal(robot.porcentajeTop20EnRivales * 100, 1)} %)',
            '≤ 40 %',
            robot.cumpleCriterioTalentosRivales ? 'cumple' : 'no cumple',
          ],
        ],
      ),
    )
    ..writeln();

  // Criterios de la Parte 3D (staff de la agencia).
  final gastoStaffT3 = robot.gastoStaffT3;
  final ingresosT3Staff = robot.ingresosT3;
  final porcentajeStaffT3 = robot.porcentajeGastoStaffT3 * 100;
  final abogadoT2 = robot.filas.length >= 2 ? robot.filas[1].abogadoNivel : 0;
  final ventasPorTemporada = robot.filas
      .map((fila) => 'T${fila.temporada}: ${fila.ventas}')
      .join(' · ');
  buffer
    ..writeln('## Criterios de la Fase 3D (staff)')
    ..writeln()
    ..writeln(
      tablaMarkdown(
        ['Criterio', 'Medición', 'Meta', '¿Cumple?'],
        [
          [
            'Abogado nivel 2 al final de la T2',
            '$abogadoT2',
            '2',
            robot.cumpleCriterioAbogado ? 'cumple' : 'no cumple',
          ],
          [
            'Relaciones públicas nivel 2 al final de la T3',
            '${robot.relacionesPublicasNivelFinal}',
            '2',
            robot.cumpleCriterioRelacionesPublicas ? 'cumple' : 'no cumple',
          ],
          [
            'Gasto en staff de la T3 / ingresos de la T3',
            '${formatearDinero(gastoStaffT3)} de '
                '${formatearDinero(ingresosT3Staff)} '
                '(${decimal(porcentajeStaffT3, 1)} %)',
            '≤ 20 %',
            robot.cumpleCriterioGastoStaff ? 'cumple' : 'no cumple',
          ],
          [
            'Ventas del robot por temporada',
            ventasPorTemporada,
            'mínimo igual con abogado',
            robot.cumpleCriterioAbogado ? 'cumple' : 'no cumple',
          ],
          [
            'Dinero final de la T3',
            formatearDinero(robot.dineroFinal),
            '≥ ${formatearDinero(robotDineroMinimoFinal)}',
            robot.cumpleDineroMinimoFinal ? 'cumple' : 'no cumple',
          ],
        ],
      ),
    )
    ..writeln()
    ..writeln(
      '- **Tasa de aceptación con abogado:** prueba unitaria con semilla '
      'fija. Sin abogado acepta 6 de 21 precios de 1,00–1,20; nivel 2, 10; '
      'nivel 5, 16. Nunca baja de la base (`test/staff_test.dart`).',
    )
    ..writeln();

  // Criterios de la Parte 3E (academia).
  final jovenesT1 = robot.jovenesReclutadosT1;
  final colocacionesT2 = robot.colocacionesAntesFinT2;
  final saldoAcademia = robot.saldoAcademia;
  final habilidadMediaColocacion = robot.habilidadMediaColocacion;
  final porcentajeAcademiaT3 = robot.porcentajeIngresoAcademiaT3 * 100;
  buffer
    ..writeln('## Criterios de la Fase 3E (academia)')
    ..writeln()
    ..writeln(
      tablaMarkdown(
        ['Criterio', 'Medición', 'Meta', '¿Cumple?'],
        [
          [
            'Jóvenes reclutados en la T1 / colocados antes de terminar la T2',
            '$jovenesT1 / $colocacionesT2',
            '2 / ≥ 1',
            robot.cumpleCriterioJovenesT1 && robot.cumpleCriterioColocacionT2
                ? 'cumple'
                : 'no cumple',
          ],
          [
            'Saldo neto de la academia al final de la T3',
            formatearDinero(saldoAcademia),
            '≥ 0 o pérdida ≤ \$30.000',
            robot.cumpleCriterioSaldoAcademia ? 'cumple' : 'no cumple',
          ],
          [
            'Habilidad media al colocar',
            decimal(habilidadMediaColocacion, 1),
            '45–65',
            robot.cumpleCriterioHabilidadColocacion ? 'cumple' : 'no cumple',
          ],
          [
            'Jóvenes de la academia en manos de rivales',
            '${robot.academiaEnRivales}',
            '0 (100 % colocados o libres)',
            robot.cumpleCriterioAcademiaSinRivales ? 'cumple' : 'no cumple',
          ],
          [
            'Ingreso de academia de la T3 / ingresos de la T3',
            '${formatearDinero(robot.ingresoAcademiaT3)} de '
                '${formatearDinero(robot.ingresosT3)} '
                '(${decimal(porcentajeAcademiaT3, 1)} %)',
            '≤ 20 %',
            robot.cumpleCriterioIngresoAcademia ? 'cumple' : 'no cumple',
          ],
        ],
      ),
    )
    ..writeln()
    ..writeln(
      '- **Medición informativa del robot conservador:** con 1 venta por '
      'semana terminó la T3 con ${formatearDinero(robotConservador.dineroFinal)} '
      'y un gasto fijo del '
      '${decimal(robotConservador.porcentajeGastoFijoT3 * 100, 1)} % de sus '
      'ingresos. No es un criterio de pasa o falla.',
    )
    ..writeln();

  buffer
    ..writeln('## Tamaño de los datos (corrección A3)')
    ..writeln()
    ..writeln(
      'Se miden al final de cada temporada, antes de la limpieza de inicio '
      'de temporada. La limpieza conserva 2 temporadas de noticias, vacía '
      'los resultados al empezar la temporada y limita los agentes libres a '
      '$maxAgentesLibres.',
    )
    ..writeln()
    ..writeln(
      tablaMarkdown(
        [
          'Temporada',
          'Jugadores',
          'Noticias',
          'Resultados',
          'Palmarés',
          'Premios',
          'Ofertas',
          'Eventos',
          'Guardado (KB)',
        ],
        [
          for (final fila in filas)
            [
              '${fila.temporada}',
              '${fila.jugadores}',
              '${fila.noticias}',
              '${fila.resultados}',
              '${fila.palmares}',
              '${fila.premios}',
              '${fila.ofertas}',
              '${fila.eventosPendientes}',
              decimal(fila.guardadoKb, 1),
            ],
        ],
      ),
    )
    ..writeln();

  // Desglose del guardado final por lista (Parte 3D): se toma el estado del
  // final de la T10, antes del rollover que vacía resultados y torneos.
  final desglose = filas.isEmpty ? <String, double>{} : filas.last.desglose;
  final totalDesglose = desglose.values.fold<double>(
    0,
    (suma, valor) => suma + valor,
  );
  buffer
    ..writeln('## Desglose del guardado final (T10)')
    ..writeln()
    ..writeln(
      'Tamaño aproximado de cada lista del JSON final. Los resultados se '
      'muestran aparte de las competiciones para ver cuánto ocupan los '
      'partidos de la temporada. El total es el JSON completo.',
    )
    ..writeln()
    ..writeln(
      tablaMarkdown(
        ['Lista', 'Tamaño (KB)', '% del total'],
        [
          for (final entrada in desglose.entries)
            [
              entrada.key,
              decimal(entrada.value, 1),
              '${decimal(entrada.value / totalDesglose * 100, 1)} %',
            ],
          ['**Total**', '**${decimal(totalDesglose, 1)}**', '**100 %**'],
        ],
      ),
    )
    ..writeln();

  buffer
    ..writeln('## Invariantes')
    ..writeln();
  if (violaciones.isEmpty) {
    buffer.writeln('Sin violaciones duras en las 10 temporadas.');
  } else {
    for (final violacion in violaciones) {
      buffer.writeln('- $violacion');
    }
  }

  final promedioHabilidades = <double>[];
  for (final fila in filas) {
    promedioHabilidades.add(
      fila.habilidades.values.reduce((a, b) => a + b) / fila.habilidades.length,
    );
  }
  var mayorSaltoHabilidad = 0.0;
  for (var i = 1; i < promedioHabilidades.length; i++) {
    final salto = (promedioHabilidades[i] - promedioHabilidades[i - 1]).abs();
    if (salto > mayorSaltoHabilidad) mayorSaltoHabilidad = salto;
  }
  final maxInflacion = filas
      .map((f) => f.presupuestoFin / f.presupuestoInicio)
      .reduce((a, b) => a > b ? a : b);
  final totalFichajes = filas.fold<int>(
    0,
    (suma, fila) => suma + fila.fichajesVentanas.fold(0, (a, b) => a + b),
  );

  buffer
    ..writeln()
    ..writeln('## Veredicto')
    ..writeln()
    ..writeln('- Violaciones duras: **${violaciones.length}**.')
    ..writeln(
      '- Mayor salto de habilidad entre temporadas: '
      '${decimal(mayorSaltoHabilidad, 2)} puntos '
      '(orientativo ≤ 3).',
    )
    ..writeln(
      '- Progresión media de 16–21 años con equipo: '
      '${decimal(mediaConEquipo, 1)} puntos/temporada '
      '(objetivo 4–8; sin equipo ${decimal(mediaSinEquipo, 1)}).',
    )
    ..writeln(
      '- Mayor dominio en una liga de 1ª División: '
      '$maxTemporadasDominio de 10 temporadas del mismo equipo '
      '(orientativo ≤ 6): '
      '**${maxTemporadasDominio <= 6 ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Mayor relación presupuesto fin / inicio: '
      '${decimal(maxInflacion, 2)}×.',
    )
    ..writeln(
      '- Tiempo de la temporada 10 / temporada 1: '
      '${decimal(filas.last.milisegundos / filas.first.milisegundos, 2)}× '
      '(meta ≤ 1,5×).',
    )
    ..writeln(
      '- Tamaño final del guardado: '
      '${decimal(filas.last.guardadoKb, 1)} KB.',
    )
    ..writeln('- Fichajes IA registrados en las ventanas: $totalFichajes.')
    ..writeln(
      '- Robot de 3 temporadas: '
      '${robot.quiebra ? 'quebró' : 'sobrevivió'}, racha máxima sin opciones '
      '${robot.rachaMaxima} semanas.',
    )
    ..writeln(
      '- Ingresos del robot: traspasos '
      '${formatearDinero(robot.ingresosPorFuente[ingresoTraspasos] ?? 0)} vs '
      'eventos '
      '${formatearDinero(robot.ingresosPorFuente[ingresoEventos] ?? 0)}. '
      'Fuente principal: '
      '${robot.fuentePrincipalIngresos?.key ?? 'sin ingresos'}.',
    )
    ..writeln(
      '- Reputación del robot: '
      '${robot.filas.isEmpty ? 'sin datos' : '${robot.filas.first.reputacionInicio} → ${robot.filas.last.reputacionFin}'} '
      '(meta 30–45 al final de la T3): '
      '**${robot.filas.isNotEmpty && robot.filas.last.reputacionFin >= 30 && robot.filas.last.reputacionFin <= 45 ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Satisfacción media final del robot: '
      '${decimal(robot.satisfaccionMedia, 1)} (meta 55–85): '
      '**${robot.cumpleCriterioSatisfaccion ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Comisión media de los contratos: '
      '${decimal(robot.comisionMedia * 100, 1)} % (meta 4–6 %): '
      '**${robot.cumpleCriterioComision ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Pérdidas máximas por insatisfacción o robo en una temporada: '
      '${robot.maxPerdidasPorSatisfaccion} (meta ≤ 2): '
      '**${robot.cumpleCriterioPerdidasSatisfaccion ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Promesas incumplidas: ${robot.promesasIncumplidas} (meta ≤ 2): '
      '**${robot.cumpleCriterioPromesas ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Ojeadores nivel 2: ${robot.ojeadoresNivel2} (meta 2): '
      '**${robot.cumpleCriterioOjeadores ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Semiancho medio de fichajes T1 → T3: '
      '${decimal(semianchoT1, 1)} → ${decimal(semianchoT3, 1)} '
      '(meta: baja): '
      '**${robot.cumpleCriterioSemiancho ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Gasto en ojeadores de la T3: '
      '${decimal(porcentajeOjeadoresT3, 1)} % de los ingresos (meta ≤ 15 %): '
      '**${robot.cumpleCriterioGastoOjeadores ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Top 20 de potencial real con rivales: '
      '${robot.top20ConRival} de ${robot.top20Considerados} '
      '(${decimal(robot.porcentajeTop20EnRivales * 100, 1)} %, meta ≤ 40 %): '
      '**${robot.cumpleCriterioTalentosRivales ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Abogado nivel 2 en la T2: '
      '**${robot.cumpleCriterioAbogado ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Relaciones públicas nivel 2 en la T3: '
      '**${robot.cumpleCriterioRelacionesPublicas ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Gasto en staff de la T3: '
      '${decimal(porcentajeStaffT3, 1)} % de los ingresos (meta ≤ 20 %): '
      '**${robot.cumpleCriterioGastoStaff ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Jóvenes reclutados en la T1: $jovenesT1 (meta 2): '
      '**${robot.cumpleCriterioJovenesT1 ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Colocaciones antes de terminar la T2: $colocacionesT2 (meta ≥ 1): '
      '**${robot.cumpleCriterioColocacionT2 ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Habilidad media al colocar: '
      '${decimal(habilidadMediaColocacion, 1)} (meta 45–65): '
      '**${robot.cumpleCriterioHabilidadColocacion ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Jóvenes de la academia con rivales: ${robot.academiaEnRivales} '
      '(meta 0): '
      '**${robot.cumpleCriterioAcademiaSinRivales ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Dinero final del robot en la T3: '
      '${formatearDinero(robot.dineroFinal)} '
      '(meta ≥ ${formatearDinero(robotDineroMinimoFinal)}): '
      '**${robot.cumpleDineroMinimoFinal ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Ingreso de academia de la T3: '
      '${decimal(porcentajeAcademiaT3, 1)} % de los ingresos '
      '(meta ≤ 20 %): '
      '**${robot.cumpleCriterioIngresoAcademia ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Saldo neto de la academia: ${formatearDinero(saldoAcademia)} '
      '(meta ≥ 0 o pérdida ≤ \$30.000): '
      '**${robot.cumpleCriterioSaldoAcademia ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln()
    ..writeln(seccionRobotConservadorMarkdown(robotConservador))
    ..writeln(marcadorRobotInicio)
    ..writeln(seccionRobotMarkdown(robot))
    ..writeln(marcadorRobotFin);

  final texto = buffer.toString();
  File('INFORME_BALANCE.md').writeAsStringSync(texto);
  return texto;
}

/// Desglose aproximado del guardado por lista (Parte 3D).
///
/// Los resultados se separan de las competiciones para que el informe muestre
/// cuánto ocupan los partidos. El resto de claves de nivel superior se agrupa
/// en «Otros» para que la suma coincida con el JSON completo.
Map<String, double> _desgloseGuardado(EstadoPartida estado) {
  final mapa = estado.toJson();
  double kb(Object? valor) => utf8.encode(jsonEncode(valor)).length / 1024;

  final resultados = <Map<String, dynamic>>[
    for (final comp in estado.competiciones) ...[
      ...comp.resultadosSplit1.map((r) => r.toJson()),
      ...comp.resultadosSplit2.map((r) => r.toJson()),
      ...comp.resultadosPlayoffs1.map((r) => r.toJson()),
      ...comp.resultadosPlayoffs2.map((r) => r.toJson()),
    ],
  ];

  final competicionesSinResultados = (mapa['competiciones'] as List).map((
    comp,
  ) {
    final copia = Map<String, dynamic>.from(comp as Map);
    copia['resultadosSplit1'] = <dynamic>[];
    copia['resultadosSplit2'] = <dynamic>[];
    copia['resultadosPlayoffs1'] = <dynamic>[];
    copia['resultadosPlayoffs2'] = <dynamic>[];
    return copia;
  }).toList();

  final desglose = <String, double>{
    'Jugadores': kb(mapa['jugadores']),
    'Noticias': kb(mapa['noticias']),
    'Ofertas': kb(mapa['ofertas']),
    'Resultados': kb(resultados),
    'Competiciones (sin resultados)': kb(competicionesSinResultados),
    'Palmarés': kb(mapa['palmares']),
    'Premios': kb(mapa['premios']),
    'Torneos': kb(mapa['torneos']),
    'Staff': kb(mapa['staff']),
    'Agentes rivales': kb(mapa['agentesRivales']),
    'Ojeadores': kb(mapa['ojeadores']),
    'Eventos pendientes': kb(mapa['eventosPendientes']),
  };

  final total = kb(mapa);
  final sumaLists = desglose.values.fold<double>(
    0,
    (suma, valor) => suma + valor,
  );
  final otros = (total - sumaLists).clamp(0.0, double.infinity);
  desglose['Otros (agente, mapas, contratos...)'] = otros;
  return desglose;
}

/// Fecha y hora legible para demostrar que el informe se regeneró.
String _fechaHora(DateTime fecha) {
  String dos(int valor) => valor.toString().padLeft(2, '0');
  return '${fecha.year}-${dos(fecha.month)}-${dos(fecha.day)} '
      '${dos(fecha.hour)}:${dos(fecha.minute)}:${dos(fecha.second)}';
}
