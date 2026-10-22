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
          progresoJoven: progresoJoven,
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
      'Las rondas 1–2 de la tabla son de la fase anterior. En esta ejecución '
      'se hicieron 3 rondas para corregir la progresión juvenil y el salto '
      'T1 → T2, anotadas abajo.',
    )
    ..writeln()
    ..writeln('### Ajustes de esta ejecución (3 rondas)')
    ..writeln()
    ..writeln(
      tablaMarkdown(
        ['Ronda', 'Cambio', 'Antes', 'Después', 'Resultado'],
        [
          [
            '1',
            'progresión juvenil',
            '30 % semanal para todos los ≤ 23 años',
            '10 % (16–19), 9 % (20–21), 5 % (22–23); '
                'sin equipo ×0,5 y suplente ×0,85',
            'Subida media 4,2 puntos/temporada, pero el salto T1 → T2 subió '
                'a 3,17 (límite 3).',
          ],
          [
            '2',
            'progresión juvenil',
            '10 / 9 / 5 %',
            '11 / 10 / 5,5 %',
            'Subida 4,4, salto 3,19 y el robot llegó a 8 semanas sin opciones '
                '(preocupante). Se revirtió en la ronda 3.',
          ],
          [
            '3',
            'progresión + reemplazos',
            '11 / 10 / 5,5 % · reemplazos -2',
            '10 / 9 / 5 % · reemplazos -3',
            'Subida 4,2; salto T1 → T2 2,69; robot con racha máxima 5. '
                'Cumplen progresión y estabilidad.',
          ],
        ],
      ),
    )
    ..writeln()
    ..writeln(
      '- **Dominio por liga (B3):** sigue por encima del criterio (17 ligas '
      'con un campeón en más de 6 de 10 temporadas). La propia corrección B3 '
      'pide medirlo y proponer un ajuste sin aplicarlo; además depende de la '
      'economía de la Fase 4 (B4), así que queda anotado como pendiente.',
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
      '- Progresión media de 16–21 años con equipo: '
      '${decimal(mediaConEquipo, 1)} puntos/temporada '
      '(objetivo 4–8; sin equipo ${decimal(mediaSinEquipo, 1)}).',
    )
    ..writeln(
      '- Mayor dominio en una liga de 1ª División: '
      '$maxTemporadasDominio de 10 temporadas del mismo equipo '
      '(orientativo ≤ 6): '
      '**${maxTemporadasDominio <= 6 ? 'cumple' : 'no cumple'}**. '
      'Se deja anotado para la Fase 4 por indicación de B3/B4.',
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
    ..writeln()
    ..writeln(marcadorRobotInicio)
    ..writeln(seccionRobotMarkdown(robot))
    ..writeln(marcadorRobotFin);

  final texto = buffer.toString();
  File('INFORME_BALANCE.md').writeAsStringSync(texto);
  return texto;
}

/// Fecha y hora legible para demostrar que el informe se regeneró.
String _fechaHora(DateTime fecha) {
  String dos(int valor) => valor.toString().padLeft(2, '0');
  return '${fecha.year}-${dos(fecha.month)}-${dos(fecha.day)} '
      '${dos(fecha.hour)}:${dos(fecha.minute)}:${dos(fecha.second)}';
}
