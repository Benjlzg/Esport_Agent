// Simulación de 10 temporadas (Fase 2.5, pasos 4–7). Genera
// INFORME_BALANCE.md y falla solo después de escribirlo si hay violaciones.
@Tags(['lento'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/mantenimiento.dart';
import 'package:esport_agent/logica/metricas.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/juego.dart';

import 'apoyo/entorno_simulacion.dart';
import 'apoyo/robot_jugador.dart';

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
        ),
      );
    }
    relojTotal.stop();

    // El robot de 3 temporadas se incluye en el mismo informe.
    final robot = await ejecutarRobotDePrueba();

    final resumen = _escribirInforme(
      filas: filas,
      estadoFinal: motor.estado!,
      violaciones: violaciones,
      milisegundosSemanas: milisegundosSemanas,
      milisegundosTotal: relojTotal.elapsedMilliseconds,
      robot: robot,
    );

    // El test falla DESPUÉS de escribir el informe para poder diagnosticar.
    expect(
      violaciones,
      isEmpty,
      reason: 'Violaciones duras:\n${violaciones.join('\n')}',
    );
    expect(resumen, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 30)));
}

String _escribirInforme({
  required List<_FilaTemporada> filas,
  required EstadoPartida estadoFinal,
  required List<String> violaciones,
  required int milisegundosSemanas,
  required int milisegundosTotal,
  required ResultadoRobot robot,
}) {
  final buffer = StringBuffer()
    ..writeln('# INFORME DE BALANCE — FASE 2.5')
    ..writeln()
    ..writeln('Generado por `test/balance_test.dart`.')
    ..writeln()
    ..writeln('- Semilla: **$semillaInforme**.')
    ..writeln(
      '- Partida: agente observador con '
      '${miles(dineroObservador)} de dinero, sin reclutar.',
    )
    ..writeln(
      '- Los eventos se resuelven solos eligiendo la opción más barata.',
    )
    ..writeln(
      '- Comando: `flutter test test/balance_test.dart --tags lento '
      '--run-skipped`. La suite normal (`flutter test`) salta estas pruebas.',
    )
    ..writeln()
    ..writeln('## Ajustes de constantes')
    ..writeln();

  const ajustes = <AjusteBalance>[
    AjusteBalance(
      ronda: 1,
      constante: 'multiplicadorValorMaximo',
      antes: '5,0',
      despues: '3,0',
      motivo:
          'El valor máximo llegaba a 6,3 M, por encima del presupuesto '
          'máximo de un equipo. Se acota para evitar valores absurdos y '
          'mantener el mercado viable.',
    ),
    AjusteBalance(
      ronda: 1,
      constante: 'probProgresoJoven',
      antes: '0,30',
      despues: '0,22',
      motivo:
          'Intentar reducir el salto de habilidad de 3,09 entre T1 y T2. '
          'El resultado empeoró (3,29), así que se revirtió en la ronda 2.',
    ),
    AjusteBalance(
      ronda: 2,
      constante: 'probProgresoJoven',
      antes: '0,22',
      despues: '0,30',
      motivo:
          'Revertir la ronda 1: la reducción de la progresión juvenil no '
          'mejoró el salto de habilidad entre temporadas.',
    ),
    AjusteBalance(
      ronda: 2,
      constante: 'ajusteHabilidadReemplazo',
      antes: '0 (constante nueva)',
      despues: '-2',
      motivo:
          'Los reemplazos por bajas se generaban al prestigio del equipo y '
          'elevaban la media. Con -2 el salto máximo baja a 2,68 y la '
          'habilidad se estabiliza.',
    ),
  ];
  buffer.writeln(
    tablaMarkdown(
      ['Ronda', 'Constante', 'Antes', 'Después', 'Motivo'],
      [
        for (final ajuste in ajustes)
          [
            '${ajuste.ronda}',
            ajuste.constante,
            ajuste.antes,
            ajuste.despues,
            ajuste.motivo,
          ],
      ],
    ),
  );
  buffer
    ..writeln()
    ..writeln(
      'Se hicieron 2 de las 3 rondas permitidas. No quedó ningún ajuste '
      'pendiente de constantes.',
    )
    ..writeln()
    ..writeln('### Correcciones de lógica')
    ..writeln()
    ..writeln(
      '- Al vencer el contrato de un titular, su equipo repone el rol en la '
      'misma semana. Sin esto, las plantillas se vaciaban con las temporadas '
      'y desde T2 había equipos sin 5 titulares.',
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

  // Dominio por liga (B3): temporadas distintas ganadas por el mismo equipo.
  final dominios = dominioPorLiga(estadoFinal);
  final topDominios = dominios.take(5).toList();
  final maxTemporadasDominio = dominios.isEmpty
      ? 0
      : dominios.first.temporadasGanadas;
  final ligasExcedidas = dominios
      .where((d) => d.temporadasGanadas > 6)
      .toList();

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
      '- Ajuste propuesto (no aplicado): repartir mejor los títulos '
      'reduciendo el determinismo de las series (menor `factorProbabilidad`) '
      'o añadiendo desgaste a los campeones. Se anota para una ronda futura.',
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
          'Ofertas IA',
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
      '- Mayor dominio en una liga de 1ª División: '
      '$maxTemporadasDominio de 10 temporadas del mismo equipo '
      '(orientativo ≤ 6).',
    )
    ..writeln(
      '- Mayor relación presupuesto fin / inicio: '
      '${decimal(maxInflacion, 2)}×.',
    )
    ..writeln('- Fichajes IA registrados en las ventanas: $totalFichajes.')
    ..writeln(
      '- Robot de 3 temporadas: '
      '${robot.quiebra ? 'quebró' : 'sobrevivió'}, racha máxima sin opciones '
      '${robot.rachaMaxima} semanas.',
    )
    ..writeln()
    ..writeln(marcadorRobotInicio)
    ..writeln(seccionRobotMarkdown(robot))
    ..writeln(marcadorRobotFin);

  final texto = buffer.toString();
  File('INFORME_BALANCE.md').writeAsStringSync(texto);
  return texto;
}
