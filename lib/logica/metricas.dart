// Contadores de simulación (Fase 2.5). Viven solo en memoria: no se guardan
// en la partida y se reinician por temporada y por ventana de fichajes.
import '../modelos/estado_partida.dart';

/// Métricas de la IA y de los eventos para los informes de balance.
class MetricasSimulacion {
  /// Temporada a la que pertenecen los contadores de temporada.
  int temporada = 1;

  /// Fichajes cerrados por la IA en la temporada actual.
  int fichajesIA = 0;

  /// Ofertas de traspaso generadas por la IA en la temporada actual.
  int ofertasIA = 0;

  /// Eventos generados en la temporada actual (incluye los informativos).
  int eventosGenerados = 0;

  /// Eventos generados con dos opciones de decisión.
  int eventosConDecision = 0;

  /// Fichajes de la IA en la ventana en curso.
  int fichajesVentana = 0;

  /// Ofertas de la IA en la ventana en curso.
  int ofertasVentana = 0;

  /// Comisiones de salario cobradas en la última semana, sin contar traspasos,
  /// renovaciones ni eventos. El resumen semanal las mezcla con el resto de
  /// movimientos (`ingresosUltimaSemana`), pero los informes de balance
  /// necesitan separarlas para no contarlas dos veces.
  int comisionesSalarioUltimaSemana = 0;

  /// Representados míos robados por un rival en la temporada actual.
  int robos = 0;

  /// Robos acumulados desde el inicio de la partida. El robot usa la
  /// diferencia entre temporadas para medir las pérdidas de cada una sin
  /// depender del reinicio de [robos] al cambiar de temporada.
  int robosTotales = 0;

  /// Representados que renunciaron por insatisfacción en la temporada actual.
  int renuncias = 0;

  /// Renuncias acumuladas desde el inicio de la partida.
  int renunciasTotales = 0;

  /// Contratos de representación vencidos sin renovar en la temporada actual.
  int contratosVencidos = 0;

  /// Contratos vencidos acumulados desde el inicio de la partida.
  int contratosVencidosTotales = 0;

  /// Promesas incumplidas acumuladas (criterio 3B: máximo 2).
  int promesasIncumplidas = 0;

  /// Anota los robos de una semana en los contadores de temporada y total.
  void registrarRobos(int cantidad) {
    if (cantidad <= 0) return;
    robos += cantidad;
    robosTotales += cantidad;
  }

  /// Anota las renuncias de una semana en los contadores de temporada y total.
  void registrarRenuncias(int cantidad) {
    if (cantidad <= 0) return;
    renuncias += cantidad;
    renunciasTotales += cantidad;
  }

  /// Anota los contratos de representación vencidos.
  void registrarContratosVencidos(int cantidad) {
    if (cantidad <= 0) return;
    contratosVencidos += cantidad;
    contratosVencidosTotales += cantidad;
  }

  /// Anota las promesas que el agente no cumplió.
  void registrarPromesasIncumplidas(int cantidad) {
    if (cantidad <= 0) return;
    promesasIncumplidas += cantidad;
  }

  /// Si cambió la temporada, reinicia los contadores de temporada y ventana.
  void asegurarTemporada(int nuevaTemporada) {
    if (nuevaTemporada == temporada) return;
    temporada = nuevaTemporada;
    fichajesIA = 0;
    ofertasIA = 0;
    eventosGenerados = 0;
    eventosConDecision = 0;
    robos = 0;
    renuncias = 0;
    contratosVencidos = 0;
    reiniciarVentana();
  }

  /// Reinicia solo los contadores de la ventana de fichajes.
  void reiniciarVentana() {
    fichajesVentana = 0;
    ofertasVentana = 0;
  }
}

/// Una violación de los límites o invariantes de la simulación.
class ViolacionInvariante {
  ViolacionInvariante(this.descripcion, {this.jugadorId, this.equipoId});

  final String descripcion;
  final String? jugadorId;
  final String? equipoId;

  @override
  String toString() {
    final contexto = <String>[
      if (jugadorId != null) 'jugador=$jugadorId',
      if (equipoId != null) 'equipo=$equipoId',
    ].join(', ');
    return contexto.isEmpty ? descripcion : '$descripcion ($contexto)';
  }
}

/// Resumen numérico de una revisión de invariantes.
class ResultadoInvariantes {
  ResultadoInvariantes({
    required this.violaciones,
    required this.maxHabilidad,
    required this.maxPotencial,
    required this.maxValorMercado,
    required this.percentil95Valor,
    required this.maxPresupuesto,
    required this.percentil95Presupuesto,
  });

  final List<ViolacionInvariante> violaciones;
  final int maxHabilidad;
  final int maxPotencial;
  final int maxValorMercado;
  final double percentil95Valor;
  final int maxPresupuesto;
  final double percentil95Presupuesto;

  bool get ok => violaciones.isEmpty;
}

/// Calcula el percentil [p] (0–1) de una lista de números.
double percentil(List<num> valores, double p) {
  if (valores.isEmpty) return 0;
  final ordenados = List<num>.from(valores)..sort();
  final posicion = ((ordenados.length - 1) * p).round();
  return ordenados[posicion].toDouble();
}

/// Revisa los límites duros del estado.
///
/// Si [revisarPlantillas] es true también comprueba que cada equipo tenga
/// cinco titulares y todos los roles de su videojuego (se usa al empezar una
/// temporada).
ResultadoInvariantes revisarInvariantes(
  EstadoPartida estado, {
  bool revisarPlantillas = false,
}) {
  final violaciones = <ViolacionInvariante>[];
  final valores = <int>[];
  final presupuestos = <int>[];
  var maxHabilidad = 0;
  var maxPotencial = 0;

  if (estado.agente.reputacion < 0 || estado.agente.reputacion > 100) {
    violaciones.add(
      ViolacionInvariante(
        'reputación del agente fuera de 0–100: ${estado.agente.reputacion}',
      ),
    );
  }

  for (final jugador in estado.jugadores) {
    if (jugador.habilidad < 1 || jugador.habilidad > 99) {
      violaciones.add(
        ViolacionInvariante(
          'habilidad fuera de 1–99: ${jugador.habilidad}',
          jugadorId: jugador.id,
        ),
      );
    }
    if (jugador.potencial < jugador.habilidad || jugador.potencial > 99) {
      violaciones.add(
        ViolacionInvariante(
          'potencial fuera de habilidad–99: ${jugador.potencial} '
          '(habilidad ${jugador.habilidad})',
          jugadorId: jugador.id,
        ),
      );
    }
    if (jugador.moral < 0 || jugador.moral > 100) {
      violaciones.add(
        ViolacionInvariante(
          'moral fuera de 0–100: ${jugador.moral}',
          jugadorId: jugador.id,
        ),
      );
    }
    if (jugador.satisfaccion < 0 || jugador.satisfaccion > 100) {
      violaciones.add(
        ViolacionInvariante(
          'satisfacción fuera de 0–100: ${jugador.satisfaccion}',
          jugadorId: jugador.id,
        ),
      );
    }
    if (jugador.representadoPorMi && jugador.expectativas.length > 2) {
      violaciones.add(
        ViolacionInvariante(
          'más de 2 expectativas: ${jugador.expectativas.length}',
          jugadorId: jugador.id,
        ),
      );
    }
    if (jugador.representadoPorMi &&
        (jugador.comisionSalarioContrato < 0.03 ||
            jugador.comisionSalarioContrato > 0.10)) {
      violaciones.add(
        ViolacionInvariante(
          'comisión de representación fuera de 0,03–0,10: '
          '${jugador.comisionSalarioContrato}',
          jugadorId: jugador.id,
        ),
      );
    }
    if (jugador.representadoPorMi &&
        jugador.semanasContratoRepresentacion < 0) {
      violaciones.add(
        ViolacionInvariante(
          'semanas de contrato de representación negativas: '
          '${jugador.semanasContratoRepresentacion}',
          jugadorId: jugador.id,
        ),
      );
    }
    if (jugador.valorMercado < 0) {
      violaciones.add(
        ViolacionInvariante(
          'valor de mercado negativo: ${jugador.valorMercado}',
          jugadorId: jugador.id,
        ),
      );
    }
    if (jugador.salarioAnual < 0) {
      violaciones.add(
        ViolacionInvariante(
          'salario anual negativo: ${jugador.salarioAnual}',
          jugadorId: jugador.id,
        ),
      );
    }
    if (jugador.habilidad > maxHabilidad) maxHabilidad = jugador.habilidad;
    if (jugador.potencial > maxPotencial) maxPotencial = jugador.potencial;
    valores.add(jugador.valorMercado);
  }

  for (final equipo in estado.equipos) {
    if (equipo.prestigio < 1 || equipo.prestigio > 100) {
      violaciones.add(
        ViolacionInvariante(
          'prestigio fuera de 1–100: ${equipo.prestigio}',
          equipoId: equipo.id,
        ),
      );
    }
    if (equipo.presupuesto < 0) {
      violaciones.add(
        ViolacionInvariante(
          'presupuesto negativo: ${equipo.presupuesto}',
          equipoId: equipo.id,
        ),
      );
    }
    presupuestos.add(equipo.presupuesto);

    if (revisarPlantillas) {
      final titulares = estado.jugadores
          .where((j) => j.equipoId == equipo.id && !j.suplente)
          .toList();
      if (titulares.length != 5) {
        violaciones.add(
          ViolacionInvariante(
            'plantilla con ${titulares.length} titulares (esperados 5)',
            equipoId: equipo.id,
          ),
        );
      }
      final roles = titulares.map((j) => j.rol).toSet();
      for (final rol in equipo.juego.roles) {
        if (!roles.contains(rol)) {
          violaciones.add(
            ViolacionInvariante(
              'falta el rol $rol entre los titulares',
              equipoId: equipo.id,
            ),
          );
        }
      }
    }
  }

  return ResultadoInvariantes(
    violaciones: violaciones,
    maxHabilidad: maxHabilidad,
    maxPotencial: maxPotencial,
    maxValorMercado: valores.isEmpty
        ? 0
        : valores.reduce((a, b) => a > b ? a : b),
    percentil95Valor: percentil(valores, 0.95),
    maxPresupuesto: presupuestos.isEmpty
        ? 0
        : presupuestos.reduce((a, b) => a > b ? a : b),
    percentil95Presupuesto: percentil(presupuestos, 0.95),
  );
}
