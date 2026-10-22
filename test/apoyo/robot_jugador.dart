// Robot de pruebas (Fase 2.5, paso 8): juega a nivel de motor durante varias
// temporadas con una estrategia sencilla y mide si la agencia sobrevive.
import 'dart:io';

import 'package:esport_agent/logica/calendario.dart';
import 'package:esport_agent/logica/formulas.dart';
import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/logica/negociacion.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/evento.dart';
import 'package:esport_agent/modelos/jugador.dart';
import 'package:esport_agent/modelos/oferta.dart';

import 'entorno_simulacion.dart';

/// Máximo de jugadores que el robot representa a la vez.
const int robotMaxRepresentados = 8;

/// El coste de representar no puede superar este porcentaje del dinero.
const double robotMaxPorcentajeDinero = 0.25;

/// Contraofertas aceptadas: al menos este porcentaje del valor de mercado.
const double robotMinimoContraoferta = 0.90;

/// Ofertas de traspaso aceptadas: al menos este porcentaje del valor.
const double robotMinimoOfertaTraspaso = 0.92;

/// Se considera que un agente libre tiene potencial alto con este margen.
const int robotMargenPotencial = 10;

/// Reserva mínima para no quedarse sin dinero para la oficina.
const int robotSemanasReserva = 8;

/// Una racha de esta cantidad de semanas sin opciones es preocupante.
const int rachaPreocupante = 8;

/// Temporadas que juega el robot del informe.
const int temporadasRobot = 3;

/// Economía real (corrección 2.5 B1): el robot empieza como un jugador nuevo.
const int robotDineroInicial = 50000;
const int robotReputacionInicial = 10;

/// Criterio orientativo de B1: no debería terminar la T3 con más de esto.
const int robotDineroMaximoFinal = 5000000;

/// Fuentes de ingreso que se miden en el informe.
const String ingresoSalarios = 'Comisiones de salario';
const String ingresoTraspasos = 'Traspasos';
const String ingresoRenovaciones = 'Renovaciones';
const String ingresoEventos = 'Eventos';

/// Orden fijo de las fuentes de ingreso en el informe.
const List<String> robotFuentesIngreso = [
  ingresoSalarios,
  ingresoTraspasos,
  ingresoRenovaciones,
  ingresoEventos,
];

/// Marcadores de la sección que el robot escribe en el informe.
const String marcadorRobotInicio = '<!-- ROBOT:INICIO -->';
const String marcadorRobotFin = '<!-- ROBOT:FIN -->';

/// Datos de una temporada jugada por el robot.
class FilaRobot {
  FilaRobot({
    required this.temporada,
    required this.dineroInicio,
    required this.dineroFin,
    required this.reputacionInicio,
    required this.reputacionFin,
    required this.decisiones,
    required this.decisionesPorTipo,
    required this.fichajes,
    required this.ventas,
    required this.eventos,
    required this.ofertasRespondidas,
    required this.semanasSinOpcion,
    required this.rachaMaxima,
  });

  final int temporada;
  final int dineroInicio;
  final int dineroFin;
  final int reputacionInicio;
  final int reputacionFin;
  final int decisiones;
  final Map<String, int> decisionesPorTipo;
  final int fichajes;
  final int ventas;
  final int eventos;
  final int ofertasRespondidas;
  final int semanasSinOpcion;
  final int rachaMaxima;
}

/// Resumen completo de la partida del robot.
class ResultadoRobot {
  ResultadoRobot({
    required this.filas,
    required this.rachaMaxima,
    required this.semanasSinOpcion,
    required this.milisegundos,
    required this.quiebra,
    required this.dineroMinimo,
    required this.temporadaMenosDinero,
    required this.semanaMenosDinero,
    required this.ingresosPorFuente,
  });

  final List<FilaRobot> filas;
  final int rachaMaxima;
  final int semanasSinOpcion;
  final int milisegundos;
  final bool quiebra;

  /// Dinero más bajo que tuvo la agencia en toda la partida.
  final int dineroMinimo;

  /// Temporada y semana en que se alcanzó [dineroMinimo]. Son null si el
  /// mínimo se alcanzó antes de jugar la primera semana.
  final int? temporadaMenosDinero;
  final int? semanaMenosDinero;

  /// Ingresos acumulados por fuente durante las 3 temporadas.
  final Map<String, int> ingresosPorFuente;

  bool get rachaPreocupanteDetectada => rachaMaxima >= rachaPreocupante;

  /// Dinero con el que terminó la última temporada jugada.
  int get dineroFinal =>
      filas.isEmpty ? robotDineroInicial : filas.last.dineroFin;

  /// true si cumple el criterio orientativo de B1 (sin quiebra y ≤ 5 M).
  bool get dentroDelCriterio =>
      !quiebra && dineroFinal <= robotDineroMaximoFinal;

  /// Fuente que más dinero aportó (null si no hubo ingresos).
  MapEntry<String, int>? get fuentePrincipalIngresos {
    MapEntry<String, int>? mejor;
    for (final fuente in robotFuentesIngreso) {
      final monto = ingresosPorFuente[fuente] ?? 0;
      if (monto <= 0) continue;
      if (mejor == null || monto > mejor.value) {
        mejor = MapEntry(fuente, monto);
      }
    }
    return mejor;
  }
}

/// Robot que recluta, vende, responde eventos y ofertas usando solo el motor.
class RobotJugador {
  RobotJugador(this.motor);

  final MotorJuego motor;

  int _rachaSinOpcion = 0;
  int _rachaMaxima = 0;
  int _semanasSinOpcion = 0;
  String _ventanaActual = '';
  final Set<String> _vendidosEnVentana = {};

  /// Dinero mínimo y semana en que se alcanzó (B1).
  int _dineroMinimo = robotDineroInicial;
  int? _temporadaMenosDinero;
  int? _semanaMenosDinero;

  /// Ingresos acumulados por fuente (B1).
  final Map<String, int> _ingresosPorFuente = {
    for (final fuente in robotFuentesIngreso) fuente: 0,
  };

  /// Juega [temporadas] temporadas completas.
  Future<ResultadoRobot> jugar({int temporadas = temporadasRobot}) async {
    final filas = <FilaRobot>[];
    final reloj = Stopwatch()..start();
    _dineroMinimo = motor.agente.dinero;
    _temporadaMenosDinero = null;
    _semanaMenosDinero = null;
    for (final fuente in robotFuentesIngreso) {
      _ingresosPorFuente[fuente] = 0;
    }

    for (var t = 1; t <= temporadas; t++) {
      final estadoInicio = motor.estado!;
      final temporadaInicio = estadoInicio.temporada;
      final dineroInicio = motor.agente.dinero;
      final reputacionInicio = motor.agente.reputacion;
      var decisiones = 0;
      var eventos = 0;
      var fichajes = 0;
      var ventas = 0;
      var ofertasRespondidas = 0;
      var semanasSinOpcionTemporada = 0;
      var rachaMaximaTemporada = 0;
      final decisionesPorTipo = <String, int>{};

      for (var semana = 1; semana <= semanasPorTemporada; semana++) {
        final sinOpcion = await _jugarSemana(
          decisionesPorTipo: decisionesPorTipo,
          alResolverEvento: (esDecision) {
            eventos++;
            if (esDecision) decisiones++;
          },
          alFichar: () => fichajes++,
          alVender: () => ventas++,
          alResponderOferta: () => ofertasRespondidas++,
        );
        if (sinOpcion) {
          _semanasSinOpcion++;
          semanasSinOpcionTemporada++;
          _rachaSinOpcion++;
          if (_rachaSinOpcion > _rachaMaxima) _rachaMaxima = _rachaSinOpcion;
          if (_rachaSinOpcion > rachaMaximaTemporada) {
            rachaMaximaTemporada = _rachaSinOpcion;
          }
        } else {
          _rachaSinOpcion = 0;
        }

        if (motor.finDelJuego) {
          // La quiebra también cuenta para el mínimo: el saldo negativo de
          // esta semana es el más bajo de la partida (B1).
          _registrarDinero(temporadaInicio, semana);
          reloj.stop();
          filas.add(
            FilaRobot(
              temporada: temporadaInicio,
              dineroInicio: dineroInicio,
              dineroFin: motor.agente.dinero,
              reputacionInicio: reputacionInicio,
              reputacionFin: motor.agente.reputacion,
              decisiones: decisiones,
              decisionesPorTipo: decisionesPorTipo,
              fichajes: fichajes,
              ventas: ventas,
              eventos: eventos,
              ofertasRespondidas: ofertasRespondidas,
              semanasSinOpcion: semanasSinOpcionTemporada,
              rachaMaxima: rachaMaximaTemporada,
            ),
          );
          return ResultadoRobot(
            filas: filas,
            rachaMaxima: _rachaMaxima,
            semanasSinOpcion: _semanasSinOpcion,
            milisegundos: reloj.elapsedMilliseconds,
            quiebra: true,
            dineroMinimo: _dineroMinimo,
            temporadaMenosDinero: _temporadaMenosDinero,
            semanaMenosDinero: _semanaMenosDinero,
            ingresosPorFuente: Map<String, int>.of(_ingresosPorFuente),
          );
        }
      }

      filas.add(
        FilaRobot(
          temporada: temporadaInicio,
          dineroInicio: dineroInicio,
          dineroFin: motor.agente.dinero,
          reputacionInicio: reputacionInicio,
          reputacionFin: motor.agente.reputacion,
          decisiones: decisiones,
          decisionesPorTipo: decisionesPorTipo,
          fichajes: fichajes,
          ventas: ventas,
          eventos: eventos,
          ofertasRespondidas: ofertasRespondidas,
          semanasSinOpcion: semanasSinOpcionTemporada,
          rachaMaxima: rachaMaximaTemporada,
        ),
      );
    }

    reloj.stop();
    return ResultadoRobot(
      filas: filas,
      rachaMaxima: _rachaMaxima,
      semanasSinOpcion: _semanasSinOpcion,
      milisegundos: reloj.elapsedMilliseconds,
      quiebra: false,
      dineroMinimo: _dineroMinimo,
      temporadaMenosDinero: _temporadaMenosDinero,
      semanaMenosDinero: _semanaMenosDinero,
      ingresosPorFuente: Map<String, int>.of(_ingresosPorFuente),
    );
  }

  /// Avanza una semana, comprueba si había opciones y actúa.
  /// Devuelve true si la semana no ofrecía ninguna opción.
  Future<bool> _jugarSemana({
    required Map<String, int> decisionesPorTipo,
    required void Function(bool esDecision) alResolverEvento,
    required void Function() alFichar,
    required void Function() alVender,
    required void Function() alResponderOferta,
  }) async {
    // La semana que se juega, para etiquetar el mínimo de dinero (B1).
    final temporadaSemana = motor.temporada;
    final semanaSemana = motor.semana;

    await motor.avanzarSemana();
    // Comisión de los salarios de esta semana (ya viene neta del inversor).
    _sumarIngreso(ingresoSalarios, motor.estado!.ingresosUltimaSemana);
    _actualizarVentana();

    final enVentana = enVentanaFichajes(motor.semana);
    final hayOpcion =
        motor.eventosPendientes.isNotEmpty ||
        motor.ofertasPendientes.isNotEmpty ||
        _candidatoReclutamiento() != null ||
        (enVentana && _jugadorVendible() != null);

    await _responderEventos(
      decisionesPorTipo: decisionesPorTipo,
      alResolverEvento: alResolverEvento,
    );
    await _responderOfertas(
      alVender: alVender,
      alResponderOferta: alResponderOferta,
    );
    final reclutado = await _reclutar();
    if (reclutado) alFichar();
    if (enVentana) {
      final vendido = await _vender();
      if (vendido) alVender();
    }

    _registrarDinero(temporadaSemana, semanaSemana);
    return !hayOpcion;
  }

  /// Suma un ingreso a su fuente (solo cantidades positivas).
  void _sumarIngreso(String fuente, int monto) {
    if (monto <= 0) return;
    _ingresosPorFuente[fuente] = (_ingresosPorFuente[fuente] ?? 0) + monto;
  }

  /// Guarda la semana con menos dinero de toda la partida (B1).
  void _registrarDinero(int temporada, int semana) {
    final dinero = motor.agente.dinero;
    if (dinero >= _dineroMinimo) return;
    _dineroMinimo = dinero;
    _temporadaMenosDinero = temporada;
    _semanaMenosDinero = semana;
  }

  void _actualizarVentana() {
    final estado = motor.estado!;
    final ventana = estado.semana <= 4
        ? 1
        : (estado.semana >= 23 && estado.semana <= 26)
        ? 2
        : (estado.semana >= 47)
        ? 3
        : 0;
    final clave = '${estado.temporada}-$ventana';
    if (clave != _ventanaActual) {
      _ventanaActual = clave;
      _vendidosEnVentana.clear();
    }
  }

  Future<void> _responderEventos({
    required Map<String, int> decisionesPorTipo,
    required void Function(bool esDecision) alResolverEvento,
  }) async {
    final pendientes = List<EventoPendiente>.of(motor.eventosPendientes);
    for (final evento in pendientes) {
      if (!motor.eventosPendientes.any((e) => e.id == evento.id)) continue;
      final opcion = evento.esDecision
          ? (evento.costoBaseB < evento.costoBaseA ? 1 : 0)
          : 0;
      if (evento.esDecision) {
        decisionesPorTipo[evento.definicionId] =
            (decisionesPorTipo[evento.definicionId] ?? 0) + 1;
      }
      alResolverEvento(evento.esDecision);
      final dineroAntes = motor.agente.dinero;
      await motor.resolverEvento(evento, opcion);
      // Los eventos pueden dar dinero (patrocinios, inversores) o cobrarlo.
      // Solo se mide el saldo positivo como fuente de ingresos.
      _sumarIngreso(ingresoEventos, motor.agente.dinero - dineroAntes);
    }
  }

  Future<void> _responderOfertas({
    required void Function() alVender,
    required void Function() alResponderOferta,
  }) async {
    final ofertas = List<Oferta>.of(motor.ofertasPendientes);
    for (final oferta in ofertas) {
      if (!motor.ofertasPendientes.any((o) => o.id == oferta.id)) continue;
      final jugador = motor.jugadorPorId(oferta.jugadorId);
      if (jugador == null) continue;

      var aceptar = false;
      if (oferta.tipo == TipoOferta.traspaso) {
        aceptar =
            enVentanaFichajes(motor.semana) &&
            oferta.monto >= jugador.valorMercado * robotMinimoOfertaTraspaso;
      } else {
        aceptar = oferta.monto >= jugador.salarioAnual;
      }

      if (aceptar) {
        final dineroAntes = motor.agente.dinero;
        final resultado = await motor.aceptarOferta(oferta);
        if (resultado.ok) {
          final fuente = oferta.tipo == TipoOferta.traspaso
              ? ingresoTraspasos
              : ingresoRenovaciones;
          _sumarIngreso(fuente, motor.agente.dinero - dineroAntes);
          if (oferta.tipo == TipoOferta.traspaso) alVender();
        }
      } else {
        await motor.rechazarOferta(oferta);
      }
      alResponderOferta();
    }
  }

  /// Recluta como máximo un agente libre por semana.
  Future<bool> _reclutar() async {
    if (motor.misJugadores.length >= robotMaxRepresentados) return false;
    final candidato = _candidatoReclutamiento();
    if (candidato == null) return false;
    final resultado = await motor.reclutar(candidato);
    return resultado.ok;
  }

  /// Mejor agente libre que cumple las reglas del robot.
  Jugador? _candidatoReclutamiento() {
    final agente = motor.agente;
    final dinero = agente.dinero;
    final maximoCoste = dinero * robotMaxPorcentajeDinero;
    final reserva = gastoOficinaSemanal * robotSemanasReserva;

    Jugador? mejor;
    for (final jugador in motor.jugadores) {
      if (jugador.representadoPorMi) continue;
      if (jugador.equipoId != null) continue;
      if (jugador.habilidad > agente.reputacion + 40) continue;
      if (jugador.potencial < jugador.habilidad + robotMargenPotencial) {
        continue;
      }
      final coste = costoRepresentar(jugador.valorMercado);
      if (coste > maximoCoste) continue;
      if (dinero - coste < reserva) continue;
      if (mejor == null ||
          jugador.potencial > mejor.potencial ||
          (jugador.potencial == mejor.potencial &&
              jugador.habilidad > mejor.habilidad)) {
        mejor = jugador;
      }
    }
    return mejor;
  }

  /// Primer jugador propio que se puede vender en esta ventana.
  Jugador? _jugadorVendible() {
    for (final jugador in motor.misJugadores) {
      if (_vendidosEnVentana.contains(jugador.id)) continue;
      // Recién fichado: no se puede vender hasta la próxima temporada.
      if (jugador.bloqueadoTraspaso(motor.temporada)) continue;
      // Periodo mínimo de representación antes de ofrecerlo (I1).
      if (jugador.semanasRepresentado < semanasMinimasRepresentacion) continue;
      if (_equipoInteresadoPara(jugador) != null) return jugador;
    }
    return null;
  }

  /// Equipo con interés, presupuesto y rondas disponibles.
  Equipo? _equipoInteresadoPara(Jugador jugador) {
    for (final equipo in motor.equiposDeJuego(jugador.juego)) {
      if (equipo.presupuesto < jugador.valorMercado) continue;
      if (motor.interesDe(jugador, equipo) == NivelInteres.sinInteres) continue;
      if (motor.bloqueado(jugador, equipo)) continue;
      if (motor.rondasRestantes(jugador, equipo) <= 0) continue;
      return equipo;
    }
    return null;
  }

  /// Vende como máximo un jugador por semana, pidiendo su valor de mercado.
  Future<bool> _vender() async {
    final jugador = _jugadorVendible();
    if (jugador == null) return false;
    final equipo = _equipoInteresadoPara(jugador);
    if (equipo == null) return false;

    final dineroAntes = motor.agente.dinero;
    final resultado = await motor.ofrecer(
      jugador: jugador,
      equipo: equipo,
      precioPedido: jugador.valorMercado,
    );
    if (resultado.respuesta == RespuestaEquipo.acepta) {
      _sumarIngreso(ingresoTraspasos, motor.agente.dinero - dineroAntes);
      _vendidosEnVentana.add(jugador.id);
      return true;
    }
    if (resultado.respuesta == RespuestaEquipo.contraoferta &&
        resultado.contraoferta >=
            jugador.valorMercado * robotMinimoContraoferta) {
      await motor.aceptarContraoferta(
        jugador: jugador,
        equipo: equipo,
        precio: resultado.contraoferta,
      );
      _sumarIngreso(ingresoTraspasos, motor.agente.dinero - dineroAntes);
      _vendidosEnVentana.add(jugador.id);
      return true;
    }
    return false;
  }
}

/// Ejecuta el robot con la semilla del informe y la economía real de un
/// jugador nuevo (50.000 y reputación 10), como pide la corrección 2.5 B1.
Future<ResultadoRobot> ejecutarRobotDePrueba({
  int semilla = semillaInforme,
}) async {
  final motor = await crearPartidaSembrada(
    semilla: semilla,
    dinero: robotDineroInicial,
    reputacion: robotReputacionInicial,
  );
  final robot = RobotJugador(motor);
  return robot.jugar();
}

/// Sección Markdown del robot para `INFORME_BALANCE.md`.
String seccionRobotMarkdown(ResultadoRobot resultado) {
  final buffer = StringBuffer()
    ..writeln('## Jugador robot (3 temporadas)')
    ..writeln()
    ..writeln(
      '- Economía real: empieza con ${formatearDinero(robotDineroInicial)} y '
      'reputación $robotReputacionInicial, igual que un jugador nuevo (B1).',
    )
    ..writeln(
      '- Recluta agentes libres con habilidad ≤ reputación + 40, potencial '
      'alto (≥ habilidad + $robotMargenPotencial) y coste ≤ '
      '${(robotMaxPorcentajeDinero * 100).round()} % del dinero; máximo '
      '$robotMaxRepresentados representados.',
    )
    ..writeln(
      '- Vende en ventana pidiendo el valor de mercado y acepta '
      'contraofertas ≥ ${(robotMinimoContraoferta * 100).round()} %.',
    )
    ..writeln(
      '- Responde eventos con la opción más barata y acepta traspasos ≥ '
      '${(robotMinimoOfertaTraspaso * 100).round()} % del valor; las '
      'renovaciones solo si el salario no baja.',
    )
    ..writeln();

  buffer.writeln(
    tablaMarkdown(
      [
        'Temporada',
        'Dinero inicio',
        'Dinero fin',
        'Reput. inicio',
        'Reput. fin',
        'Decisiones',
        'Fichajes',
        'Ventas',
        'Eventos',
        'Ofertas',
        'Semanas sin opción',
        'Racha máx.',
      ],
      [
        for (final fila in resultado.filas)
          [
            '${fila.temporada}',
            miles(fila.dineroInicio),
            miles(fila.dineroFin),
            '${fila.reputacionInicio}',
            '${fila.reputacionFin}',
            '${fila.decisiones}',
            '${fila.fichajes}',
            '${fila.ventas}',
            '${fila.eventos}',
            '${fila.ofertasRespondidas}',
            '${fila.semanasSinOpcion}',
            '${fila.rachaMaxima}',
          ],
      ],
    ),
  );

  final principal = resultado.fuentePrincipalIngresos;
  buffer
    ..writeln()
    ..writeln('### Dinero e ingresos')
    ..writeln()
    ..writeln(
      '- Semana con menos dinero: '
      '${resultado.temporadaMenosDinero == null ? 'antes de la primera semana' : 'T${resultado.temporadaMenosDinero} · S${resultado.semanaMenosDinero}'} '
      '(${formatearDinero(resultado.dineroMinimo)}).',
    )
    ..writeln(
      '- Principal fuente de ingresos: '
      '${principal == null ? 'sin ingresos' : '${principal.key} (${formatearDinero(principal.value)})'}.',
    )
    ..writeln(
      '- Criterio B1 (sin quiebra y ≤ '
      '${formatearDinero(robotDineroMaximoFinal)} al final de la T3): '
      '**${resultado.dentroDelCriterio ? 'cumple' : 'no cumple'}** '
      '(dinero final ${formatearDinero(resultado.dineroFinal)}).',
    )
    ..writeln()
    ..writeln(
      tablaMarkdown(
        ['Fuente de ingreso', 'Total'],
        [
          for (final fuente in robotFuentesIngreso)
            [fuente, miles(resultado.ingresosPorFuente[fuente] ?? 0)],
        ],
      ),
    );

  final porTipo = <String, int>{};
  for (final fila in resultado.filas) {
    for (final entrada in fila.decisionesPorTipo.entries) {
      porTipo[entrada.key] = (porTipo[entrada.key] ?? 0) + entrada.value;
    }
  }
  final tipos = porTipo.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  buffer
    ..writeln()
    ..writeln('### Decisiones por tipo')
    ..writeln();
  if (tipos.isEmpty) {
    buffer.writeln('No hubo decisiones de evento.');
  } else {
    buffer.writeln(
      tablaMarkdown(
        ['Evento', 'Veces'],
        [
          for (final entrada in tipos) [entrada.key, '${entrada.value}'],
        ],
      ),
    );
  }

  final totalDecisiones = resultado.filas.fold<int>(
    0,
    (suma, fila) => suma + fila.decisiones,
  );
  final totalEventos = resultado.filas.fold<int>(
    0,
    (suma, fila) => suma + fila.eventos,
  );
  final totalFichajes = resultado.filas.fold<int>(
    0,
    (suma, fila) => suma + fila.fichajes,
  );
  final totalVentas = resultado.filas.fold<int>(
    0,
    (suma, fila) => suma + fila.ventas,
  );

  buffer
    ..writeln()
    ..writeln('### Veredicto del robot')
    ..writeln()
    ..writeln('- Quiebra: **${resultado.quiebra ? 'sí' : 'no'}**.')
    ..writeln(
      '- Eventos respondidos: $totalEventos ($totalDecisiones con decisión).',
    )
    ..writeln('- Fichajes propios: $totalFichajes · ventas: $totalVentas.')
    ..writeln(
      '- Semanas sin ninguna opción: ${resultado.semanasSinOpcion} · '
      'racha máxima: ${resultado.rachaMaxima} '
      '(preocupante desde $rachaPreocupante).',
    )
    ..writeln(
      '- Racha preocupante: '
      '**${resultado.rachaPreocupanteDetectada ? 'sí' : 'no'}**.',
    )
    ..writeln('- Tiempo del robot: ${resultado.milisegundos} ms.');

  return buffer.toString();
}

/// Inserta o reemplaza la sección del robot en el informe de balance.
void actualizarSeccionRobot(ResultadoRobot resultado) {
  final archivo = File('INFORME_BALANCE.md');
  var texto = archivo.existsSync() ? archivo.readAsStringSync() : '';
  final seccion = seccionRobotMarkdown(resultado);
  final bloque = '$marcadorRobotInicio\n$seccion\n$marcadorRobotFin';

  final inicio = texto.indexOf(marcadorRobotInicio);
  if (inicio >= 0) {
    final fin = texto.indexOf(marcadorRobotFin, inicio);
    if (fin >= 0) {
      texto =
          '${texto.substring(0, inicio)}$bloque'
          '${texto.substring(fin + marcadorRobotFin.length)}';
    } else {
      texto = '$texto\n$bloque\n';
    }
  } else {
    texto = '$texto\n\n$bloque\n';
  }
  archivo.writeAsStringSync(texto);
}
