// Robot de pruebas (Fase 2.5, paso 8): juega a nivel de motor durante varias
// temporadas con una estrategia sencilla y mide si la agencia sobrevive.
import 'dart:io';
import 'dart:math';

import 'package:esport_agent/logica/calendario.dart';
import 'package:esport_agent/logica/formulas.dart';
import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/logica/negociacion.dart';
import 'package:esport_agent/logica/ojeadores.dart';
import 'package:esport_agent/logica/satisfaccion.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/evento.dart';
import 'package:esport_agent/modelos/juego.dart';
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

/// Mejora mínima de potencial para cambiar a un representado por un agente
/// libre cuando la cartera está llena (Parte 3A). Con 0 se acepta igualar el
/// potencial y mejorar la habilidad.
const int robotMejoraReemplazo = 0;

/// Reserva mínima para no quedarse sin dinero para la oficina.
const int robotSemanasReserva = 8;

/// Política de ojeadores del robot (Parte 3C): dos ojeadores de nivel 2 si
/// tiene reserva para 30 semanas de su salario total.
const int robotNumeroOjeadores = 2;
const int robotOjeadoresNivel = 2;
const int robotSemanasReservaOjeadores = 30;

/// Una racha de esta cantidad de semanas sin opciones es preocupante.
/// La competencia de la Parte 3A puede llenar la cartera antes de la ventana;
/// 12 semanas cubren ese hueco sin marcar como fallo una cartera estable.
const int rachaPreocupante = 12;

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

/// Fuentes de gasto que se miden en el informe.
const String gastoOficina = 'Oficina';
const String gastoReclutamientos = 'Reclutamientos';
const String gastoEventos = 'Eventos';
const String gastoOjeadores = 'Ojeadores';

/// Orden fijo de las fuentes de gasto en el informe.
const List<String> robotFuentesGasto = [
  gastoOficina,
  gastoReclutamientos,
  gastoOjeadores,
  gastoEventos,
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
    required this.perdidasPorRobo,
    this.perdidasPorInsatisfaccion = 0,
    this.perdidasPorContrato = 0,
    this.promesasIncumplidas = 0,
    this.semianchoMedioFichajes = 0,
    this.ingresosTemporada = 0,
    this.gastoOjeadores = 0,
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

  /// Representados míos que un rival me robó durante esta temporada.
  final int perdidasPorRobo;

  /// Representados que renunciaron por insatisfacción en esta temporada.
  final int perdidasPorInsatisfaccion;

  /// Contratos de representación vencidos sin renovar en esta temporada.
  final int perdidasPorContrato;

  /// Promesas incumplidas en esta temporada.
  final int promesasIncumplidas;

  /// Semiancho medio del rango visible de los fichajes de la temporada.
  final double semianchoMedioFichajes;

  /// Ingresos totales de la temporada (para el criterio del 15 %).
  final int ingresosTemporada;

  /// Gasto en salarios de ojeadores durante la temporada.
  final int gastoOjeadores;
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
    required this.gastosPorFuente,
    required this.jugadoresSinAgenteIniciales,
    required this.jugadoresSinAgenteEnRivales,
    this.satisfaccionMedia = 0,
    this.comisionMedia = 0,
    this.ojeadoresNivel2 = 0,
    this.top20ConRival = 0,
    this.top20Considerados = 0,
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

  /// Gastos acumulados por fuente durante las 3 temporadas.
  final Map<String, int> gastosPorFuente;

  /// Jugadores que empezaron la partida sin agente (incluye jugadores con
  /// equipo). Es la base del criterio del 40 % de la Parte 3A.
  final int jugadoresSinAgenteIniciales;

  /// De esos jugadores, cuántos terminaron representados por un rival.
  final int jugadoresSinAgenteEnRivales;

  /// Satisfacción media de la cartera al terminar la simulación.
  final double satisfaccionMedia;

  /// Comisión media de los contratos de representación al terminar.
  final double comisionMedia;

  /// Ojeadores de nivel 2 contratados por el robot (Parte 3C).
  final int ojeadoresNivel2;

  /// Jugadores del top 20 de potencial real que están con un rival.
  final int top20ConRival;

  /// Tamaño del top 20 medido (normalmente 20).
  final int top20Considerados;

  /// Semiancho medio de los fichajes de la primera temporada.
  double get semianchoT1 =>
      filas.isEmpty ? 0 : filas.first.semianchoMedioFichajes;

  /// Semiancho medio de los fichajes de la última temporada.
  double get semianchoT3 =>
      filas.isEmpty ? 0 : filas.last.semianchoMedioFichajes;

  /// Criterio 3C: el semiancho medio de los fichajes baja de T1 a T3.
  bool get cumpleCriterioSemiancho =>
      filas.length >= 3 && semianchoT3 <= semianchoT1;

  /// Criterio 3C: dos ojeadores de nivel 2 contratados.
  bool get cumpleCriterioOjeadores => ojeadoresNivel2 >= robotNumeroOjeadores;

  /// Criterio 3C: gasto en ojeadores ≤ 15 % de los ingresos de la T3.
  bool get cumpleCriterioGastoOjeadores {
    if (filas.isEmpty) return false;
    final fila = filas.last;
    if (fila.ingresosTemporada <= 0) return false;
    return fila.gastoOjeadores <= fila.ingresosTemporada * 0.15;
  }

  /// Criterio 3C: ≤ 40 % del top 20 de potencial real está con rivales.
  bool get cumpleCriterioTalentosRivales {
    if (top20Considerados == 0) return true;
    return top20ConRival <= top20Considerados * 0.40;
  }

  /// Porcentaje del top 20 que está con rivales.
  double get porcentajeTop20EnRivales =>
      top20Considerados == 0 ? 0 : top20ConRival / top20Considerados;

  /// Pérdidas por robo sumadas a todas las temporadas.
  int get perdidasPorRobo =>
      filas.fold(0, (total, fila) => total + fila.perdidasPorRobo);

  /// Máximo de representados robados en una sola temporada.
  int get maxPerdidasPorRobo => filas.isEmpty
      ? 0
      : filas
            .map((fila) => fila.perdidasPorRobo)
            .reduce((a, b) => a > b ? a : b);

  /// Criterio 3A: el robot pierde como máximo un representado por temporada.
  bool get cumpleCriterioRobos => maxPerdidasPorRobo <= 1;

  /// Menor cantidad de reclutamientos en una temporada.
  int get minimoFichajesPorTemporada => filas.isEmpty
      ? 0
      : filas.map((fila) => fila.fichajes).reduce((a, b) => a < b ? a : b);

  /// Criterio 3A: el robot sigue consiguiendo al menos 5 reclutamientos.
  bool get cumpleCriterioFichajes => minimoFichajesPorTemporada >= 5;

  /// Criterio 3A: reputación final entre 30 y 45.
  bool get cumpleCriterioReputacion {
    final reputacion = reputacionFinal;
    return reputacion >= 30 && reputacion <= 45;
  }

  /// Porcentaje de los jugadores que empezaron sin agente y acabaron con un
  /// rival. Debe ser ≤ 40 % en la Parte 3A.
  double get porcentajeEnRivales => jugadoresSinAgenteIniciales == 0
      ? 0
      : jugadoresSinAgenteEnRivales / jugadoresSinAgenteIniciales;

  bool get cumpleCriterioRivales => porcentajeEnRivales <= 0.40;

  /// Pérdidas por insatisfacción sumadas a todas las temporadas.
  int get perdidasPorInsatisfaccion =>
      filas.fold(0, (total, fila) => total + fila.perdidasPorInsatisfaccion);

  /// Máximo de representados perdidos en una temporada por insatisfacción.
  int get maxPerdidasPorInsatisfaccion => filas.isEmpty
      ? 0
      : filas
            .map((fila) => fila.perdidasPorInsatisfaccion)
            .reduce((a, b) => a > b ? a : b);

  /// Máximo de pérdidas por insatisfacción o robo en una temporada.
  int get maxPerdidasPorSatisfaccion => filas.isEmpty
      ? 0
      : filas
            .map(
              (fila) => fila.perdidasPorInsatisfaccion + fila.perdidasPorRobo,
            )
            .reduce((a, b) => a > b ? a : b);

  /// Criterio 3B: máximo 1–2 pérdidas por insatisfacción o robo por temporada.
  bool get cumpleCriterioPerdidasSatisfaccion =>
      maxPerdidasPorSatisfaccion <= 2;

  /// Criterio 3B: satisfacción media final entre 55 y 85.
  bool get cumpleCriterioSatisfaccion =>
      satisfaccionMedia >= 55 && satisfaccionMedia <= 85;

  /// Criterio 3B: comisión media de los contratos entre 4 % y 6 %.
  bool get cumpleCriterioComision =>
      comisionMedia >= 0.04 && comisionMedia <= 0.06;

  /// Promesas incumplidas acumuladas en toda la partida.
  int get promesasIncumplidas =>
      filas.fold(0, (total, fila) => total + fila.promesasIncumplidas);

  /// Criterio 3B: como máximo 2 castigos por promesa incumplida.
  bool get cumpleCriterioPromesas => promesasIncumplidas <= 2;

  /// Reputación al final de la última temporada jugada.
  int get reputacionFinal =>
      filas.isEmpty ? robotReputacionInicial : filas.last.reputacionFin;

  int get ingresosTotales =>
      ingresosPorFuente.values.fold(0, (suma, monto) => suma + monto);

  int get gastosTotales =>
      gastosPorFuente.values.fold(0, (suma, monto) => suma + monto);

  /// Diferencia entre el saldo teórico y el real. Debe ser 0: si no, hay un
  /// movimiento de dinero que el informe no está clasificando.
  int get descuadre =>
      robotDineroInicial + ingresosTotales - gastosTotales - dineroFinal;

  bool get cuadra => descuadre == 0;

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

  /// Semianchos de los fichajes de la temporada en curso (Parte 3C).
  final List<double> _semianchosFichajesTemporada = [];

  /// Evita contratar ojeadores más de una vez.
  bool _ojeadoresContratados = false;

  /// Gasto en ojeadores de la temporada en curso.
  int _gastoOjeadoresTemporada = 0;

  /// Dinero mínimo y semana en que se alcanzó (B1).
  int _dineroMinimo = robotDineroInicial;
  int? _temporadaMenosDinero;
  int? _semanaMenosDinero;

  /// Ingresos acumulados por fuente (B1).
  final Map<String, int> _ingresosPorFuente = {
    for (final fuente in robotFuentesIngreso) fuente: 0,
  };

  /// Gastos acumulados por fuente (oficina, reclutamientos y eventos).
  final Map<String, int> _gastosPorFuente = {
    for (final fuente in robotFuentesGasto) fuente: 0,
  };

  /// Jugadores sin agente al empezar el robot, para medir cuántos acaban en
  /// manos de un rival al final de la T3 (Parte 3A).
  Set<String> _sinAgenteIniciales = {};

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
    for (final fuente in robotFuentesGasto) {
      _gastosPorFuente[fuente] = 0;
    }
    _sinAgenteIniciales = motor.jugadores
        .where((j) => j.sinAgente)
        .map((j) => j.id)
        .toSet();

    // Política fija de 3C: dos ojeadores nivel 2 si hay reserva para 30
    // semanas de su salario total.
    await _contratarOjeadoresIniciales();

    for (var t = 1; t <= temporadas; t++) {
      final estadoInicio = motor.estado!;
      final temporadaInicio = estadoInicio.temporada;
      final dineroInicio = motor.agente.dinero;
      final reputacionInicio = motor.agente.reputacion;
      final ingresosInicioTemporada = _ingresosTotalesActuales();
      _semianchosFichajesTemporada.clear();
      _gastoOjeadoresTemporada = 0;
      final robosInicioTemporada = motor.metricas.robosTotales;
      final renunciasInicioTemporada = motor.metricas.renunciasTotales;
      final contratosInicioTemporada = motor.metricas.contratosVencidosTotales;
      final promesasInicioTemporada = motor.metricas.promesasIncumplidas;
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
              perdidasPorRobo:
                  motor.metricas.robosTotales - robosInicioTemporada,
              perdidasPorInsatisfaccion:
                  motor.metricas.renunciasTotales - renunciasInicioTemporada,
              perdidasPorContrato:
                  motor.metricas.contratosVencidosTotales -
                  contratosInicioTemporada,
              promesasIncumplidas:
                  motor.metricas.promesasIncumplidas - promesasInicioTemporada,
              semianchoMedioFichajes: _semianchoMedioFichajes(),
              ingresosTemporada:
                  _ingresosTotalesActuales() - ingresosInicioTemporada,
              gastoOjeadores: _gastoOjeadoresTemporada,
            ),
          );
          final sinAgenteEnRivales = _jugadoresSinAgenteEnRivales();
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
            gastosPorFuente: Map<String, int>.of(_gastosPorFuente),
            jugadoresSinAgenteIniciales: _sinAgenteIniciales.length,
            jugadoresSinAgenteEnRivales: sinAgenteEnRivales,
            satisfaccionMedia: _satisfaccionMedia(),
            comisionMedia: _comisionMedia(),
            ojeadoresNivel2: _ojeadoresNivel2(),
            top20ConRival: _top20ConRival(),
            top20Considerados: _top20Considerados(),
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
          perdidasPorRobo: motor.metricas.robosTotales - robosInicioTemporada,
          perdidasPorInsatisfaccion:
              motor.metricas.renunciasTotales - renunciasInicioTemporada,
          perdidasPorContrato:
              motor.metricas.contratosVencidosTotales -
              contratosInicioTemporada,
          promesasIncumplidas:
              motor.metricas.promesasIncumplidas - promesasInicioTemporada,
          semianchoMedioFichajes: _semianchoMedioFichajes(),
          ingresosTemporada:
              _ingresosTotalesActuales() - ingresosInicioTemporada,
          gastoOjeadores: _gastoOjeadoresTemporada,
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
      gastosPorFuente: Map<String, int>.of(_gastosPorFuente),
      jugadoresSinAgenteIniciales: _sinAgenteIniciales.length,
      jugadoresSinAgenteEnRivales: _jugadoresSinAgenteEnRivales(),
      satisfaccionMedia: _satisfaccionMedia(),
      comisionMedia: _comisionMedia(),
      ojeadoresNivel2: _ojeadoresNivel2(),
      top20ConRival: _top20ConRival(),
      top20Considerados: _top20Considerados(),
    );
  }

  /// Cuántos de los jugadores que empezaron sin agente terminaron con un
  /// rival. Solo cuenta a los que siguen en la partida.
  int _jugadoresSinAgenteEnRivales() {
    return motor.jugadores
        .where(
          (j) => _sinAgenteIniciales.contains(j.id) && j.representadoPorRival,
        )
        .length;
  }

  /// Satisfacción media actual de la cartera del robot.
  double _satisfaccionMedia() {
    final jugadores = motor.misJugadores;
    if (jugadores.isEmpty) return 0;
    final suma = jugadores.fold<int>(
      0,
      (total, jugador) => total + jugador.satisfaccion,
    );
    return suma / jugadores.length;
  }

  /// Comisión media actual de los contratos de representación.
  double _comisionMedia() {
    final jugadores = motor.misJugadores;
    if (jugadores.isEmpty) return 0;
    final suma = jugadores.fold<double>(
      0,
      (total, jugador) => total + jugador.comisionSalarioContrato,
    );
    return suma / jugadores.length;
  }

  /// Suma actual de ingresos de todas las fuentes (para medir la T3).
  int _ingresosTotalesActuales() =>
      _ingresosPorFuente.values.fold(0, (suma, monto) => suma + monto);

  /// Media de semiancho de los fichajes de la temporada en curso.
  double _semianchoMedioFichajes() {
    if (_semianchosFichajesTemporada.isEmpty) return 0;
    final suma = _semianchosFichajesTemporada.fold<double>(
      0,
      (total, ancho) => total + ancho,
    );
    return suma / _semianchosFichajesTemporada.length;
  }

  /// Ojeadores nivel 2 que siguen contratados al final.
  int _ojeadoresNivel2() =>
      motor.ojeadores.where((o) => o.nivel == robotOjeadoresNivel).length;

  /// Tamaño del top de potencial real que se mide (máximo 20).
  int _top20Considerados() => min(20, motor.jugadores.length);

  /// Cuántos del top 20 de potencial real están representados por un rival.
  int _top20ConRival() {
    final top = List<Jugador>.from(motor.jugadores)
      ..sort((a, b) => b.potencial.compareTo(a.potencial));
    return top.take(20).where((j) => j.representadoPorRival).length;
  }

  /// Contrata dos ojeadores nivel 2 en los dos pares juego+región con más
  /// agentes libres de 21 años o menos, si hay reserva para 30 semanas.
  Future<void> _contratarOjeadoresIniciales() async {
    if (_ojeadoresContratados) return;
    final costeSemanal =
        salarioOjeador(robotOjeadoresNivel) * robotNumeroOjeadores;
    if (motor.agente.dinero < costeSemanal * robotSemanasReservaOjeadores) {
      return;
    }

    final equipos = {for (final equipo in motor.equipos) equipo.id: equipo};
    final conteo = <(Juego, String), int>{};
    for (final jugador in motor.jugadores) {
      if (!jugador.sinAgente || jugador.oculto) continue;
      if (jugador.edad > 21) continue;
      final region = jugador.equipoId == null
          ? jugador.region
          : equipos[jugador.equipoId]?.region;
      if (region == null) continue;
      final par = (jugador.juego, region);
      conteo[par] = (conteo[par] ?? 0) + 1;
    }
    if (conteo.isEmpty) return;

    final pares = conteo.entries.toList()
      ..sort((a, b) {
        final porCantidad = b.value.compareTo(a.value);
        if (porCantidad != 0) return porCantidad;
        return a.key.$2.compareTo(b.key.$2);
      });
    var contratados = 0;
    for (final par in pares) {
      if (contratados >= robotNumeroOjeadores) break;
      final yaExiste = motor.ojeadores.any(
        (o) => o.juego == par.key.$1 && o.region == par.key.$2,
      );
      if (yaExiste) continue;
      final resultado = await motor.contratarOjeador(
        juego: par.key.$1,
        region: par.key.$2,
        nivel: robotOjeadoresNivel,
      );
      if (resultado.ok) contratados++;
    }
    _ojeadoresContratados = true;
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
    // Se lee la métrica específica: `ingresosUltimaSemana` incluye además los
    // traspasos y eventos de la semana anterior y duplicaría esas fuentes.
    _sumarIngreso(
      ingresoSalarios,
      motor.metricas.comisionesSalarioUltimaSemana,
    );
    // La oficina se cobra siempre al avanzar, aunque no haya otras acciones.
    _sumarGasto(gastoOficina, gastoOficinaSemanal);
    // Los ojeadores cobran su salario semanal junto a la oficina.
    final gastoOjeadoresSemana = motor.gastoOjeadoresSemanal;
    _sumarGasto(gastoOjeadores, gastoOjeadoresSemana);
    _gastoOjeadoresTemporada += gastoOjeadoresSemana;
    _actualizarVentana();

    final enVentana = enVentanaFichajes(motor.semana);
    final haySatisfaccion = motor.representadosQueQuierenHablar.isNotEmpty;
    final hayOpcion =
        motor.eventosPendientes.isNotEmpty ||
        motor.ofertasPendientes.isNotEmpty ||
        _hayReclutamientoPosible() ||
        haySatisfaccion ||
        (enVentana && _jugadorVendible() != null);

    await _responderSatisfaccion();
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

  /// Suma un gasto a su fuente (solo cantidades positivas).
  void _sumarGasto(String fuente, int monto) {
    if (monto <= 0) return;
    _gastosPorFuente[fuente] = (_gastosPorFuente[fuente] ?? 0) + monto;
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

  /// Responde a los jugadores que quieren hablar: promete si hay dinero para
  /// sostener la agencia; si no, los ignora. Es la política pedida en 3B.
  Future<void> _responderSatisfaccion() async {
    final jugadores = List<Jugador>.of(motor.representadosQueQuierenHablar);
    final reserva = gastoOficinaSemanal * robotSemanasReserva;
    for (final jugador in jugadores) {
      if (!jugador.quiereHablar || !jugador.representadoPorMi) continue;
      if (motor.agente.dinero > reserva) {
        await motor.prometerMejora(jugador);
      } else {
        await motor.ignorarJugador(jugador);
      }
    }

    // Renueva los contratos de representación antes de que expiren. Sin esto
    // la cartera se vaciaría sola cada 52 semanas.
    for (final jugador in List<Jugador>.of(motor.misJugadores)) {
      if (jugador.semanasContratoRepresentacion >
          umbralSemanasRenovacionRepresentacion) {
        continue;
      }
      final maxima = motor.comisionMaximaAceptablePara(jugador, 52);
      if (maxima < comisionRepresentacionMin) continue;
      var comision = jugador.comisionSalarioContrato;
      if (comision > maxima) comision = maxima;
      if (comision < comisionRepresentacionMin) continue;
      await motor.renegociarContratoRepresentacion(
        jugador,
        comision: comision,
        duracionSemanas: 52,
      );
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
      // Cada dirección se anota en su propia fuente.
      final delta = motor.agente.dinero - dineroAntes;
      if (delta >= 0) {
        _sumarIngreso(ingresoEventos, delta);
      } else {
        _sumarGasto(gastoEventos, -delta);
      }
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

  /// Recluta como máximo un agente libre por semana. Si la cartera está llena,
  /// sustituye al representado con menor potencial visible cuando la mejora
  /// compensa. Nunca mira el potencial real (Parte 3C).
  Future<bool> _reclutar() async {
    final candidato = _candidatoReclutamiento();
    if (candidato == null) return false;
    final potencialCandidato = puntoMedioPotencial(candidato);
    if (motor.misJugadores.length >= robotMaxRepresentados) {
      final peor = _peorRepresentado();
      if (peor == null ||
          potencialCandidato <
              puntoMedioPotencial(peor) + robotMejoraReemplazo) {
        return false;
      }
      await motor.dejarDeRepresentar(peor);
    }
    final dineroAntes = motor.agente.dinero;
    final resultado = await motor.reclutar(candidato);
    if (resultado.ok) {
      _sumarGasto(gastoReclutamientos, dineroAntes - motor.agente.dinero);
      _semianchosFichajesTemporada.add(semianchoVisibleDe(candidato));
    }
    return resultado.ok;
  }

  /// true si el robot puede fichar esta semana, aunque tenga que liberar un
  /// cupo sustituyendo a su peor representado.
  bool _hayReclutamientoPosible() {
    final candidato = _candidatoReclutamiento();
    if (candidato == null) return false;
    if (motor.misJugadores.length < robotMaxRepresentados) return true;
    final peor = _peorRepresentado();
    return peor != null &&
        puntoMedioPotencial(candidato) >=
            puntoMedioPotencial(peor) + robotMejoraReemplazo;
  }

  /// Representado propio con menor potencial visible (desempata por habilidad).
  Jugador? _peorRepresentado() {
    Jugador? peor;
    for (final jugador in motor.misJugadores) {
      final potencial = puntoMedioPotencial(jugador);
      final potencialPeor = peor == null ? 0.0 : puntoMedioPotencial(peor);
      if (peor == null ||
          potencial < potencialPeor ||
          (potencial == potencialPeor && jugador.habilidad < peor.habilidad)) {
        peor = jugador;
      }
    }
    return peor;
  }

  /// Mejor agente libre que cumple las reglas del robot.
  Jugador? _candidatoReclutamiento() {
    final agente = motor.agente;
    final dinero = agente.dinero;
    final maximoCoste = dinero * robotMaxPorcentajeDinero;
    final reserva = gastoOficinaSemanal * robotSemanasReserva;

    Jugador? mejor;
    for (final jugador in motor.jugadores) {
      // Solo agentes libres: ni míos ni de un rival (Parte 3A).
      if (!jugador.sinAgente) continue;
      // Los talentos ocultos no son visibles para el robot.
      if (jugador.oculto) continue;
      if (jugador.habilidad > agente.reputacion + 40) continue;
      final potencialVisible = puntoMedioPotencial(jugador);
      if (potencialVisible < jugador.habilidad + robotMargenPotencial) {
        continue;
      }
      // La Parte 3B hace que un jugador sin equipo o con expectativas
      // incumplidas se marche. El robot solo ficha carteras que ya pueden
      // estar satisfechas: así cuida a sus representados como pide la fase.
      final equipo = jugador.equipoId == null
          ? null
          : motor.equipoPorId(jugador.equipoId!);
      final expectativas = generarExpectativas(
        jugador: jugador,
        equipo: equipo,
      );
      final cumplidas = expectativas.every(
        (clave) =>
            expectativaCumplida(jugador: jugador, clave: clave, equipo: equipo),
      );
      if (!cumplidas) continue;
      final coste = costoRepresentar(jugador.valorMercado);
      if (coste > maximoCoste) continue;
      if (dinero - coste < reserva) continue;
      if (mejor == null ||
          potencialVisible > puntoMedioPotencial(mejor) ||
          (potencialVisible == puntoMedioPotencial(mejor) &&
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
      'alto (≥ habilidad + $robotMargenPotencial), coste ≤ '
      '${(robotMaxPorcentajeDinero * 100).round()} % del dinero y '
      'expectativas ya cumplidas; máximo $robotMaxRepresentados '
      'representados. Si la cartera está llena, sustituye al representado '
      'con menos potencial cuando el agente libre lo iguala o mejora.',
    )
    ..writeln(
      '- Ojeadores (3C): contrata $robotNumeroOjeadores de nivel '
      '$robotOjeadoresNivel en los dos pares juego+región con más agentes '
      'libres de 21 años o menos, si tiene reserva para '
      '$robotSemanasReservaOjeadores semanas de su salario total.',
    )
    ..writeln(
      '- Ficha usando el punto medio del rango visible del potencial, no el '
      'potencial real.',
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
        'Robos',
        'Renuncias',
        'Contratos',
        'Promesas',
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
            '${fila.perdidasPorRobo}',
            '${fila.perdidasPorInsatisfaccion}',
            '${fila.perdidasPorContrato}',
            '${fila.promesasIncumplidas}',
          ],
      ],
    ),
  );

  buffer
    ..writeln()
    ..writeln('### Ojeadores (3C)')
    ..writeln()
    ..writeln(
      tablaMarkdown(
        [
          'Temporada',
          'Semiancho medio fichajes',
          'Gasto ojeadores',
          'Ingresos temporada',
          '% ojeadores',
        ],
        [
          for (final fila in resultado.filas)
            [
              '${fila.temporada}',
              decimal(fila.semianchoMedioFichajes, 1),
              miles(fila.gastoOjeadores),
              miles(fila.ingresosTemporada),
              fila.ingresosTemporada == 0
                  ? '—'
                  : '${decimal(fila.gastoOjeadores / fila.ingresosTemporada * 100, 1)} %',
            ],
        ],
      ),
    )
    ..writeln()
    ..writeln(
      '- Ojeadores nivel $robotOjeadoresNivel contratados: '
      '${resultado.ojeadoresNivel2} (meta $robotNumeroOjeadores).',
    )
    ..writeln(
      '- Semiancho medio de fichajes: T1 '
      '${decimal(resultado.semianchoT1, 1)} → T3 '
      '${decimal(resultado.semianchoT3, 1)} (meta: baja).',
    );

  final principal = resultado.fuentePrincipalIngresos;
  final ingresosTotales = resultado.ingresosTotales;
  final gastosTotales = resultado.gastosTotales;
  buffer
    ..writeln()
    ..writeln('### Dinero, ingresos y gastos')
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
          ['**Total**', '**${miles(ingresosTotales)}**'],
        ],
      ),
    )
    ..writeln()
    ..writeln('### Gastos')
    ..writeln()
    ..writeln(
      tablaMarkdown(
        ['Fuente de gasto', 'Total'],
        [
          for (final fuente in robotFuentesGasto)
            [fuente, miles(resultado.gastosPorFuente[fuente] ?? 0)],
          ['**Total**', '**${miles(gastosTotales)}**'],
        ],
      ),
    )
    ..writeln()
    ..writeln('### Cuadre del dinero')
    ..writeln()
    ..writeln(
      tablaMarkdown(
        ['Concepto', 'Importe'],
        [
          ['Dinero inicial', miles(robotDineroInicial)],
          ['Ingresos', miles(ingresosTotales)],
          ['Gastos', '−${miles(gastosTotales)}'],
          ['Dinero final', miles(resultado.dineroFinal)],
          [
            'Descuadre',
            resultado.cuadra ? '0 (cuadra)' : miles(resultado.descuadre),
          ],
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
    ..writeln(
      '- Satisfacción media final: '
      '${resultado.satisfaccionMedia.toStringAsFixed(1)} '
      '(meta 55–85): '
      '**${resultado.cumpleCriterioSatisfaccion ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Comisión media de los contratos: '
      '${(resultado.comisionMedia * 100).toStringAsFixed(1)} % '
      '(meta 4–6 %): '
      '**${resultado.cumpleCriterioComision ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Máximo de pérdidas por insatisfacción o robo en una temporada: '
      '${resultado.maxPerdidasPorSatisfaccion} (meta ≤ 2): '
      '**${resultado.cumpleCriterioPerdidasSatisfaccion ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Promesas incumplidas: ${resultado.promesasIncumplidas} (meta ≤ 2): '
      '**${resultado.cumpleCriterioPromesas ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Ojeadores nivel $robotOjeadoresNivel: '
      '${resultado.ojeadoresNivel2} (meta $robotNumeroOjeadores): '
      '**${resultado.cumpleCriterioOjeadores ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Semiancho medio de fichajes T1 → T3: '
      '${decimal(resultado.semianchoT1, 1)} → '
      '${decimal(resultado.semianchoT3, 1)} (meta: baja): '
      '**${resultado.cumpleCriterioSemiancho ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Gasto en ojeadores de la T3: '
      '${decimal(resultado.filas.isEmpty ? 0 : resultado.filas.last.gastoOjeadores / max(1, resultado.filas.last.ingresosTemporada) * 100, 1)} % '
      'de los ingresos (meta ≤ 15 %): '
      '**${resultado.cumpleCriterioGastoOjeadores ? 'cumple' : 'no cumple'}**.',
    )
    ..writeln(
      '- Top 20 de potencial real con rivales: '
      '${resultado.top20ConRival} de ${resultado.top20Considerados} '
      '(${decimal(resultado.porcentajeTop20EnRivales * 100, 1)} %, meta ≤ 40 %): '
      '**${resultado.cumpleCriterioTalentosRivales ? 'cumple' : 'no cumple'}**.',
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
