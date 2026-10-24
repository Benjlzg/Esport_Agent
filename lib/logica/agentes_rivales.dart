// Agentes rivales (Parte 3A).
//
// Aquí viven las reglas de la competencia entre agentes: generación de
// rivales, carteras, acciones semanales, disputas por jugadores sin agente,
// robos de representados insatisfechos, "Convencerlo", reputación, ranking y
// el premio Agente del Año.
import 'dart:math';

import '../datos/nombres_aleatorios.dart';
import '../modelos/agente_rival.dart';
import '../modelos/estado_partida.dart';
import '../modelos/historial.dart';
import '../modelos/juego.dart';
import '../modelos/jugador.dart';
import '../modelos/noticia.dart';
import 'calendario.dart';
import 'formulas.dart';
import 'mercado.dart';
import 'ojeadores.dart';

// ------------------- CONSTANTES DE BALANCE -------------------

/// Cantidad de agentes rivales que se generan al crear la partida.
const int agentesRivalesMin = 15;
const int agentesRivalesMax = 25;
const int numAgentesRivales = 18;

/// Rango de reputación inicial de los rivales.
const int reputacionRivalMinima = 20;
const int reputacionRivalMaxima = 90;

/// Dinero inicial de un rival = reputación × esta cantidad.
const int dineroRivalPorReputacion = 2500;

/// Cada rival empieza representando entre 2 y 5 jugadores sin agente.
const int carteraInicialMinima = 2;
const int carteraInicialMaxima = 5;

/// Jugadores sin equipo y sin agente que se reservan para el mercado al
/// generar los rivales. Sin esta reserva, 18 rivales podrían quedarse con los
/// 40 agentes libres iniciales y el jugador no tendría a quién reclutar.
const int reservaLibresIniciales = 25;

/// Probabilidad de que un rival haga su acción de perfil cada semana.
const double probActividadRivalSemanal = 0.20;

/// Probabilidad de que un rival intente robar a un representado mío.
const double probIntentoRoboPorRivalSemanal = 0.08;

/// Probabilidad base de que aparezca un rival al reclamar un jugador.
const double probDisputaRivalBase = 0.25;

/// Solo disputan rivales cuya reputación no supere la mía por más de esto.
const int ventajaDisputaRivalMax = 25;

/// Bonus de atractivo del especialista si el jugador es de su videojuego.
const int bonusEspecialistaAtractivo = 3;

/// El azar del atractivo es un entero uniforme de 0 a este valor.
const int azarAtractivoMax = 10;

/// Límites de probabilidad de robo y de convencer.
const double probabilidadRoboBase = 0.25;
const double probabilidadRoboMinima = 0.05;
const double probabilidadRoboMaxima = 0.75;
const double probabilidadConvencerBase = 0.20;
const double probabilidadConvencerMinima = 0.05;
const double probabilidadConvencerMaxima = 0.60;

/// Divisor de la diferencia de atractivo en las dos fórmulas.
const double divisorDiferenciaAtractivo = 50;

/// Semanas de enfriamiento tras cambiar de agente.
const int semanasEnfriamientoCambioAgente = 26;

/// Semanas de espera después de fallar un "Convencer".
const int semanasEsperaConvencerFallido = 13;

/// Reputación que pierde un rival arruinado al cambiar de temporada.
const int penalizacionRivalArruinado = 1;

/// Satisfacción por debajo de la cual se puede intentar un robo.
const int satisfaccionMinimaRobo = 35;

/// Comisión inicial que paga cualquier agente al fichar (5 % del valor).
const double comisionInicialRival = 0.05;

/// Máximo de jugadores en la cartera de cada perfil. Ningún rival ficha por
/// encima de su máximo: si está lleno, solo puede vender o renovar.
const Map<PerfilRival, int> maxCarteraPorPerfil = {
  PerfilRival.agresivo: 15,
  PerfilRival.cazatalentos: 20,
  PerfilRival.negociador: 12,
  PerfilRival.comercial: 20,
  PerfilRival.conservador: 8,
  PerfilRival.especialista: 12,
};

/// Comisión de salario semanal que cobra cada perfil.
const Map<PerfilRival, double> comisionSalarioPorPerfil = {
  PerfilRival.agresivo: 0.06,
  PerfilRival.cazatalentos: 0.05,
  PerfilRival.negociador: 0.04,
  PerfilRival.comercial: 0.03,
  PerfilRival.conservador: 0.04,
  PerfilRival.especialista: 0.05,
};

/// Clave interna para identificar a mi agencia en los cálculos de atractivo.
const String idMiAgencia = 'yo';

// ------------------- CONSULTAS DE CARTERA -------------------

/// Jugadores que pertenecen a la cartera de un rival.
List<Jugador> carteraDeRival(EstadoPartida estado, AgenteRival rival) {
  return estado.jugadores
      .where(
        (j) => !j.representadoPorMi && !j.enAcademia && j.agenteId == rival.id,
      )
      .toList();
}

/// Cantidad de representados de un rival.
int numeroRepresentadosDeRival(EstadoPartida estado, AgenteRival rival) =>
    carteraDeRival(estado, rival).length;

/// Suma del valor de mercado de la cartera de un rival.
int valorCarteraDeRival(EstadoPartida estado, AgenteRival rival) {
  return carteraDeRival(
    estado,
    rival,
  ).fold(0, (suma, j) => suma + j.valorMercado);
}

/// Valor de mi cartera normal. La academia no cuenta hasta que el joven se
/// coloca en un equipo.
int valorCarteraMia(EstadoPartida estado) {
  return estado.jugadores
      .where((j) => j.representadoPorMi && !j.enAcademia)
      .fold(0, (suma, j) => suma + j.valorMercado);
}

/// Busca el rival que representa a un jugador, o null si no es de un rival.
AgenteRival? rivalDeJugador(EstadoPartida estado, Jugador jugador) {
  if (jugador.representadoPorMi) return null;
  final id = jugador.agenteId;
  if (id == null || id == idMiAgencia) return null;
  for (final rival in estado.agentesRivales) {
    if (rival.id == id) return rival;
  }
  return null;
}

/// Puntos de ranking: reputación + un punto por cada millón de cartera.
int puntosRankingAgente({required int reputacion, required int valorCartera}) {
  return reputacion + (valorCartera / 1000000).round();
}

/// Una fila del ranking de agentes, conmigo incluido.
class FilaRankingAgente {
  FilaRankingAgente({
    required this.esYo,
    required this.nombre,
    required this.perfil,
    required this.reputacion,
    required this.representados,
    required this.valorCartera,
    this.rivalId,
  });

  /// true si la fila es mi agencia.
  final bool esYo;

  /// Id del rival (null en mi fila).
  final String? rivalId;

  /// Nombre visible del agente.
  final String nombre;

  /// Perfil del rival (null en mi fila).
  final PerfilRival? perfil;

  final int reputacion;
  final int representados;
  final int valorCartera;

  /// Puntos que ordenan el ranking.
  int get puntos =>
      puntosRankingAgente(reputacion: reputacion, valorCartera: valorCartera);
}

/// Ranking completo, de mejor a peor. Desempata por valor de cartera y luego
/// por nombre para que el orden sea estable.
List<FilaRankingAgente> rankingAgentes(EstadoPartida estado) {
  final filas = <FilaRankingAgente>[];
  final misJugadores = estado.jugadores.where(
    (j) => j.representadoPorMi && !j.enAcademia,
  );
  filas.add(
    FilaRankingAgente(
      esYo: true,
      nombre: estado.agente.nombre,
      perfil: null,
      reputacion: estado.agente.reputacion,
      representados: misJugadores.length,
      valorCartera: misJugadores.fold(0, (suma, j) => suma + j.valorMercado),
    ),
  );
  for (final rival in estado.agentesRivales) {
    final cartera = carteraDeRival(estado, rival);
    filas.add(
      FilaRankingAgente(
        esYo: false,
        rivalId: rival.id,
        nombre: rival.nombre,
        perfil: rival.perfil,
        reputacion: rival.reputacion,
        representados: cartera.length,
        valorCartera: cartera.fold(0, (suma, j) => suma + j.valorMercado),
      ),
    );
  }
  filas.sort((a, b) {
    final porPuntos = b.puntos.compareTo(a.puntos);
    if (porPuntos != 0) return porPuntos;
    final porCartera = b.valorCartera.compareTo(a.valorCartera);
    if (porCartera != 0) return porCartera;
    return a.nombre.compareTo(b.nombre);
  });
  return filas;
}

// ------------------- GENERACIÓN -------------------

/// Valor de mercado seguro: si un estado de prueba no lo calculó todavía,
/// se usa la fórmula en vez de tratar al jugador como si valiera cero.
int _valorDe(Jugador jugador) =>
    jugador.valorMercado > 0 ? jugador.valorMercado : valorMercadoDe(jugador);

/// Costo que paga un agente rival al fichar a un jugador (5 % de su valor).
int costoFichajeRival(Jugador jugador) =>
    (_valorDe(jugador) * comisionInicialRival).round();

/// Genera el nombre de un agente rival sin repetir los ya usados.
String _nombreRivalUnico(Random rnd, Set<String> usados) {
  final base =
      '${nombres[rnd.nextInt(nombres.length)]} '
      '${apellidos[rnd.nextInt(apellidos.length)]}';
  var candidato = base;
  var numero = 2;
  while (usados.contains(candidato)) {
    candidato = '$base $numero';
    numero++;
  }
  usados.add(candidato);
  return candidato;
}

/// Lista de perfiles con al menos 2 cazatalentos y 2 especialistas.
List<PerfilRival> _perfilesParaGenerar(Random rnd) {
  final perfiles = <PerfilRival>[
    PerfilRival.cazatalentos,
    PerfilRival.cazatalentos,
    PerfilRival.especialista,
    PerfilRival.especialista,
  ];
  const relleno = [
    PerfilRival.agresivo,
    PerfilRival.negociador,
    PerfilRival.comercial,
    PerfilRival.conservador,
    PerfilRival.cazatalentos,
    PerfilRival.especialista,
  ];
  while (perfiles.length < numAgentesRivales) {
    perfiles.add(relleno[rnd.nextInt(relleno.length)]);
  }
  perfiles.shuffle(rnd);
  return perfiles;
}

/// Candidatos para la cartera inicial. Se priorizan jugadores sin equipo,
/// después los suplentes y por último los jugadores de 2ª División.
List<Jugador> _candidatosCarteraInicial(
  EstadoPartida estado,
  AgenteRival rival,
  Random rnd,
) {
  final sinEquipo = <Jugador>[];
  final suplentes = <Jugador>[];
  final segundaDivision = <Jugador>[];
  final equipos = {for (final e in estado.equipos) e.id: e};

  for (final j in estado.jugadores) {
    if (!j.sinAgente) continue;
    if (j.oculto || j.candidatoAcademia || j.enAcademia) continue;
    if (!aceptaRepresentacion(
      reputacion: rival.reputacion,
      habilidad: j.habilidad,
    )) {
      continue;
    }
    if (j.equipoId == null) {
      sinEquipo.add(j);
    } else if (j.suplente) {
      suplentes.add(j);
    } else if (equipos[j.equipoId]?.division == 2) {
      segundaDivision.add(j);
    }
  }
  sinEquipo.shuffle(rnd);
  suplentes.shuffle(rnd);
  segundaDivision.shuffle(rnd);
  // Se reservan algunos jugadores sin equipo para que el mercado siga vivo.
  final disponiblesSinEquipo = max(
    0,
    sinEquipo.length - reservaLibresIniciales,
  );
  return [
    ...sinEquipo.take(disponiblesSinEquipo),
    ...suplentes,
    ...segundaDivision,
  ];
}

/// Marca a un jugador como representado por un rival. No cobra nada: el
/// costo se cobra en `_ficharRival`, porque la cartera inicial es gratuita.
void _asignarRival(Jugador jugador, AgenteRival rival) {
  jugador.representadoPorMi = false;
  jugador.agenteId = rival.id;
  jugador.semanasRepresentado = 0;
}

/// Sincroniza `agenteId` con `representadoPorMi` y limpia ids de rivales que
/// ya no existen. No genera rivales ni consume números aleatorios.
void normalizarRepresentaciones(EstadoPartida estado) {
  final idsRivales = estado.agentesRivales.map((r) => r.id).toSet();
  for (final j in estado.jugadores) {
    if (j.representadoPorMi) {
      j.agenteId = idMiAgencia;
    } else if (j.agenteId == idMiAgencia) {
      j.agenteId = null;
    }
    if (j.agenteId != null &&
        j.agenteId != idMiAgencia &&
        !idsRivales.contains(j.agenteId)) {
      j.agenteId = null;
    }
    j.satisfaccion = j.satisfaccion.clamp(0, 100);
    if (j.semanasEnfriamientoAgente < 0) j.semanasEnfriamientoAgente = 0;
    if (j.semanasEsperaConvencer < 0) j.semanasEsperaConvencer = 0;
  }
}

/// Garantiza que la partida tenga agentes rivales y que las representaciones
/// estén sincronizadas con `agenteId`.
///
/// Se llama al crear una partida y al cargar una guardada. En partidas v3–v9
/// la lista llega vacía y aquí se generan los rivales y sus carteras.
void asegurarAgentesRivales(EstadoPartida estado, Random rnd) {
  normalizarRepresentaciones(estado);
  if (estado.agentesRivales.isNotEmpty) return;

  final perfiles = _perfilesParaGenerar(rnd);
  final nombresUsados = <String>{};
  for (var i = 0; i < numAgentesRivales; i++) {
    final perfil = perfiles[i];
    final reputacion =
        reputacionRivalMinima +
        rnd.nextInt(reputacionRivalMaxima - reputacionRivalMinima + 1);
    estado.agentesRivales.add(
      AgenteRival(
        id: 'r${i.toString().padLeft(3, '0')}',
        nombre: _nombreRivalUnico(rnd, nombresUsados),
        pais: paises[rnd.nextInt(paises.length)],
        perfil: perfil,
        juegoEspecialidad: perfil == PerfilRival.especialista
            ? Juego.values[rnd.nextInt(Juego.values.length)]
            : null,
        reputacion: reputacion,
        dinero: reputacion * dineroRivalPorReputacion,
      ),
    );
  }

  // Cartera inicial: cada rival ficha entre 2 y 5 jugadores sin agente.
  for (final rival in estado.agentesRivales) {
    final cantidad =
        carteraInicialMinima +
        rnd.nextInt(carteraInicialMaxima - carteraInicialMinima + 1);
    final maximo = maxCarteraPorPerfil[rival.perfil]!;
    final candidatos = _candidatosCarteraInicial(estado, rival, rnd);
    for (final jugador in candidatos.take(min(cantidad, maximo))) {
      _asignarRival(jugador, rival);
    }
  }
}

// ------------------- ATRACTIVO Y PROBABILIDADES -------------------

/// Atractivo de un agente para un jugador concreto.
///
/// `reputacion` y `comisionCobrada` son los del agente; `bonusEspecialista`
/// solo se suma si el rival trabaja el videojuego del jugador. `azar` es un
/// entero entre 0 y [azarAtractivoMax].
double atractivoAgente({
  required int reputacion,
  required double comisionCobrada,
  required int azar,
  int bonusEspecialista = 0,
}) {
  return reputacion +
      (comisionInicialRival - comisionCobrada) * 200 +
      bonusEspecialista +
      azar;
}

/// Atractivo de mi agencia. En 3A todavía no hay contratos negociados: la
/// comisión es el 5 % fijo de siempre.
double atractivoMio({required EstadoPartida estado, required int azar}) {
  return atractivoAgente(
    reputacion: estado.agente.reputacion,
    comisionCobrada: comisionInicialRival,
    azar: azar,
  );
}

/// Atractivo de un rival para un jugador concreto.
double atractivoRival({
  required AgenteRival rival,
  required Jugador jugador,
  required int azar,
}) {
  final bonus =
      rival.perfil == PerfilRival.especialista &&
          rival.juegoEspecialidad == jugador.juego
      ? bonusEspecialistaAtractivo
      : 0;
  return atractivoAgente(
    reputacion: rival.reputacion,
    comisionCobrada: comisionSalarioPorPerfil[rival.perfil]!,
    azar: azar,
    bonusEspecialista: bonus,
  );
}

/// Probabilidad de que un rival consiga robar a un representado mío.
double probabilidadRobo({
  required EstadoPartida estado,
  required AgenteRival rival,
  required Jugador jugador,
  required Random rnd,
}) {
  final atractivoDelRival = atractivoRival(
    rival: rival,
    jugador: jugador,
    azar: rnd.nextInt(azarAtractivoMax + 1),
  );
  final atractivoMioActual = atractivoMio(
    estado: estado,
    azar: rnd.nextInt(azarAtractivoMax + 1),
  );
  return (probabilidadRoboBase +
          (atractivoDelRival - atractivoMioActual) / divisorDiferenciaAtractivo)
      .clamp(probabilidadRoboMinima, probabilidadRoboMaxima);
}

/// Probabilidad de convencer a un jugador de un rival.
///
/// Se usa el azar medio (5) para que la probabilidad que ve el jugador en la
/// interfaz sea la misma que se aplica al intentarlo.
double probabilidadConvencerJugador({
  required EstadoPartida estado,
  required AgenteRival rival,
  required Jugador jugador,
}) {
  final atractivoMioActual = atractivoMio(
    estado: estado,
    azar: azarAtractivoMax ~/ 2,
  );
  final atractivoDelRival = atractivoRival(
    rival: rival,
    jugador: jugador,
    azar: azarAtractivoMax ~/ 2,
  );
  return (probabilidadConvencerBase +
          (atractivoMioActual - atractivoDelRival) / divisorDiferenciaAtractivo)
      .clamp(probabilidadConvencerMinima, probabilidadConvencerMaxima);
}

/// Rivales que pueden competir por un jugador cuando intento reclutarlo.
List<AgenteRival> rivalesQuePuedenDisputar(
  EstadoPartida estado,
  Jugador jugador,
) {
  return estado.agentesRivales.where((rival) {
    if (rival.reputacion > estado.agente.reputacion + ventajaDisputaRivalMax) {
      return false;
    }
    final cartera = carteraDeRival(estado, rival);
    if (cartera.length >= maxCarteraPorPerfil[rival.perfil]!) return false;
    // Debe poder pagar la comisión inicial del 5 %.
    if (rival.dinero < costoFichajeRival(jugador)) return false;
    return true;
  }).toList();
}

/// Resultado de una disputa entre mi agencia y un rival.
class ResultadoDisputa {
  ResultadoDisputa({
    required this.rival,
    required this.ganoRival,
    required this.atractivoMio,
    required this.atractivoRival,
  });

  final AgenteRival rival;
  final bool ganoRival;
  final double atractivoMio;
  final double atractivoRival;
}

/// Resuelve una disputa entre mi agencia y un rival con una semilla dada.
ResultadoDisputa resolverDisputa({
  required EstadoPartida estado,
  required AgenteRival rival,
  required Jugador jugador,
  required Random rnd,
}) {
  final mio = atractivoMio(
    estado: estado,
    azar: rnd.nextInt(azarAtractivoMax + 1),
  );
  final suyo = atractivoRival(
    rival: rival,
    jugador: jugador,
    azar: rnd.nextInt(azarAtractivoMax + 1),
  );
  return ResultadoDisputa(
    rival: rival,
    // En un empate gano yo: el rival debe superarme para llevárselo.
    ganoRival: suyo > mio,
    atractivoMio: mio,
    atractivoRival: suyo,
  );
}

// ------------------- ACCIONES SEMANALES -------------------

/// Resultado de ejecutar las acciones de todos los rivales una semana.
class ResultadoSemanaRivales {
  ResultadoSemanaRivales();

  /// Noticias que el motor debe registrar (fichajes, ventas y robos).
  final List<Noticia> noticias = [];

  /// Mensajes de robo que la interfaz muestra como aviso destacado.
  final List<String> avisosRobo = [];

  /// Cuántos representados míos fueron robados esta semana.
  int robos = 0;

  /// Cuántos fichajes cerraron los rivales.
  int fichajes = 0;

  /// Cuántas ventas cerraron los rivales.
  int ventas = 0;
}

/// Cierto si el rival puede incorporar un jugador más a su cartera.
bool puedeFicharRival(EstadoPartida estado, AgenteRival rival) {
  final maximo = maxCarteraPorPerfil[rival.perfil]!;
  return carteraDeRival(estado, rival).length < maximo;
}

/// Ejecuta una semana completa de los rivales, en orden aleatorio.
ResultadoSemanaRivales ejecutarSemanaRivales({
  required EstadoPartida estado,
  required Random rnd,
}) {
  final resultado = ResultadoSemanaRivales();
  final rivales = List<AgenteRival>.from(estado.agentesRivales)..shuffle(rnd);

  for (final rival in rivales) {
    // Un rival arruinado no actúa: solo espera la penalización de temporada.
    if (rival.dinero < 0) continue;

    // 1) Cobra su comisión de salario por los representados con equipo.
    final comision = comisionSalarioPorPerfil[rival.perfil]!;
    for (final jugador in carteraDeRival(estado, rival)) {
      if (jugador.equipoId == null) continue;
      final semanal = calcularSalarioSemanal(jugador.salarioAnual);
      rival.dinero += (semanal * comision).round();
    }

    // 2) Con cierta probabilidad hace una acción según su perfil.
    if (rnd.nextDouble() < probActividadRivalSemanal) {
      _accionDePerfil(estado, rival, rnd, resultado);
    }

    // 3) Con cierta probabilidad intenta robar a un representado insatisfecho.
    if (rnd.nextDouble() < probIntentoRoboPorRivalSemanal) {
      _intentarRobo(estado, rival, rnd, resultado);
    }
  }
  return resultado;
}

/// Acción semanal de un rival según su perfil.
void _accionDePerfil(
  EstadoPartida estado,
  AgenteRival rival,
  Random rnd,
  ResultadoSemanaRivales resultado,
) {
  switch (rival.perfil) {
    case PerfilRival.agresivo:
      _ficharMejorHabilidad(estado, rival, resultado, minimo: 70);
    case PerfilRival.cazatalentos:
      _ficharMejorJoven(estado, rival, resultado);
    case PerfilRival.negociador:
      if (!_venderRepresentado(estado, rival, rnd, resultado)) {
        _renovarContratos(estado, rival);
      }
    case PerfilRival.comercial:
      if (!_venderRepresentado(estado, rival, rnd, resultado)) {
        _ficharBarato(estado, rival, resultado);
      }
    case PerfilRival.conservador:
      _ficharConservador(estado, rival, resultado);
    case PerfilRival.especialista:
      _ficharEspecialista(estado, rival, resultado);
  }
}

/// Jugadores sin agente que cumplen una condición, ordenados por [ordenar].
List<Jugador> _candidatos(
  EstadoPartida estado,
  AgenteRival rival, {
  required bool Function(Jugador) condicion,
  required int Function(Jugador, Jugador) ordenar,
}) {
  if (!puedeFicharRival(estado, rival)) return const [];
  final lista = estado.jugadores.where((j) {
    if (!j.sinAgente) return false;
    // Los rivales no ven ni fichan talentos ocultos, candidatos de la
    // academia ni jóvenes que ya entrenan en ella.
    if (j.oculto || j.candidatoAcademia || j.enAcademia) return false;
    if (rival.dinero < costoFichajeRival(j)) return false;
    return condicion(j);
  }).toList()..sort(ordenar);
  return lista;
}

/// Ficha al jugador sin agente con más habilidad (mínimo [minimo]).
void _ficharMejorHabilidad(
  EstadoPartida estado,
  AgenteRival rival,
  ResultadoSemanaRivales resultado, {
  required int minimo,
}) {
  final candidatos = _candidatos(
    estado,
    rival,
    condicion: (j) => j.habilidad >= minimo,
    ordenar: (a, b) => b.habilidad.compareTo(a.habilidad),
  );
  if (candidatos.isEmpty) return;
  _ficharRival(estado, rival, candidatos.first, resultado);
}

/// Ficha al joven con mayor margen de potencial estimado (edad ≤ 20 y
/// margen ≥ 12). El rival no ve el potencial real (Parte 3C).
void _ficharMejorJoven(
  EstadoPartida estado,
  AgenteRival rival,
  ResultadoSemanaRivales resultado,
) {
  final candidatos = _candidatos(
    estado,
    rival,
    condicion: (j) =>
        j.edad <= 20 && potencialEstimadoDe(j) - j.habilidad >= 12,
    ordenar: (a, b) {
      final margenA = potencialEstimadoDe(a) - a.habilidad;
      final margenB = potencialEstimadoDe(b) - b.habilidad;
      final porMargen = margenB.compareTo(margenA);
      if (porMargen != 0) return porMargen;
      return potencialEstimadoDe(b).compareTo(potencialEstimadoDe(a));
    },
  );
  if (candidatos.isEmpty) return;
  _ficharRival(estado, rival, candidatos.first, resultado);
}

/// Ficha un jugador barato (valor < $100.000) con el mayor potencial
/// estimado.
void _ficharBarato(
  EstadoPartida estado,
  AgenteRival rival,
  ResultadoSemanaRivales resultado,
) {
  final candidatos = _candidatos(
    estado,
    rival,
    condicion: (j) => _valorDe(j) < 100000,
    ordenar: (a, b) {
      final porPotencial = potencialEstimadoDe(b)
          .compareTo(potencialEstimadoDe(a));
      if (porPotencial != 0) return porPotencial;
      return b.habilidad.compareTo(a.habilidad);
    },
  );
  if (candidatos.isEmpty) return;
  _ficharRival(estado, rival, candidatos.first, resultado);
}

/// El conservador solo ficha si su dinero supera 10 veces el costo.
void _ficharConservador(
  EstadoPartida estado,
  AgenteRival rival,
  ResultadoSemanaRivales resultado,
) {
  final candidatos = _candidatos(
    estado,
    rival,
    condicion: (j) => rival.dinero > 10 * costoFichajeRival(j),
    ordenar: (a, b) => b.habilidad.compareTo(a.habilidad),
  );
  if (candidatos.isEmpty) return;
  _ficharRival(estado, rival, candidatos.first, resultado);
}

/// El especialista solo trabaja los jugadores de su videojuego.
void _ficharEspecialista(
  EstadoPartida estado,
  AgenteRival rival,
  ResultadoSemanaRivales resultado,
) {
  final juego = rival.juegoEspecialidad;
  if (juego == null) return;
  final candidatos = _candidatos(
    estado,
    rival,
    condicion: (j) => j.juego == juego,
    ordenar: (a, b) {
      final porHabilidad = b.habilidad.compareTo(a.habilidad);
      if (porHabilidad != 0) return porHabilidad;
      return potencialEstimadoDe(b).compareTo(potencialEstimadoDe(a));
    },
  );
  if (candidatos.isEmpty) return;
  _ficharRival(estado, rival, candidatos.first, resultado);
}

/// Cierra el fichaje de un jugador por parte de un rival.
bool _ficharRival(
  EstadoPartida estado,
  AgenteRival rival,
  Jugador jugador,
  ResultadoSemanaRivales resultado,
) {
  if (!puedeFicharRival(estado, rival)) return false;
  final costo = costoFichajeRival(jugador);
  if (rival.dinero < costo) return false;

  rival.dinero -= costo;
  _asignarRival(jugador, rival);
  // Al cambiar de agente se activa el enfriamiento para evitar ping-pong.
  jugador.semanasEnfriamientoAgente = semanasEnfriamientoCambioAgente;
  resultado.fichajes++;
  resultado.noticias.add(
    Noticia(
      semana: estado.semana,
      temporada: estado.temporada,
      texto:
          '${rival.nombre} ficha a ${jugador.nick} '
          '(${jugador.rol}, ${jugador.habilidad} de habilidad).',
      tipo: TipoNoticia.fichaje,
    ),
  );
  return true;
}

/// Vende un representado del rival a un equipo interesado. Solo en ventana.
bool _venderRepresentado(
  EstadoPartida estado,
  AgenteRival rival,
  Random rnd,
  ResultadoSemanaRivales resultado,
) {
  if (!enVentanaFichajes(estado.semana)) return false;

  final equipos = {for (final e in estado.equipos) e.id: e};
  for (final jugador in carteraDeRival(estado, rival)) {
    if (jugador.equipoId == null) continue;
    if (jugador.bloqueadoTraspaso(estado.temporada)) continue;
    final origenId = jugador.equipoId!;
    final valor = _valorDe(jugador);
    final compradores = estado.equipos.where((equipo) {
      if (equipo.id == origenId) return false;
      if (equipo.juego != jugador.juego) return false;
      if (equipo.presupuesto < valor) return false;
      return equipoInteresado(
        habilidad: jugador.habilidad,
        prestigio: equipo.prestigio,
      );
    }).toList();
    if (compradores.isEmpty) continue;

    final comprador = compradores[rnd.nextInt(compradores.length)];
    final origen = equipos[origenId];
    final comision = comisionPorTransferencia(valor);
    if (origen != null) origen.presupuesto += valor - comision;
    comprador.presupuesto -= valor;
    rival.dinero += comision;

    // El jugador desplazado en ese rol baja a suplente, igual que en los
    // traspasos del jugador. Sin esto el comprador podría quedar con 6
    // titulares y romper el invariante de 5 por equipo.
    for (final otro in estado.jugadores) {
      if (otro.id != jugador.id &&
          otro.equipoId == comprador.id &&
          otro.rol == jugador.rol &&
          !otro.suplente) {
        otro.suplente = true;
        resultado.noticias.add(
          Noticia(
            semana: estado.semana,
            temporada: estado.temporada,
            texto:
                '${otro.nick} pasa a suplente tras la llegada de '
                '${jugador.nick} a ${comprador.nombre}.',
            tipo: TipoNoticia.evento,
          ),
        );
      }
    }
    for (final sobrante in recortarSuplentes(estado, comprador)) {
      resultado.noticias.add(
        Noticia(
          semana: estado.semana,
          temporada: estado.temporada,
          texto:
              '${sobrante.nick} quedó libre para hacer sitio en '
              '${comprador.nombre}.',
          tipo: TipoNoticia.evento,
        ),
      );
    }

    jugador.equipoId = comprador.id;
    jugador.suplente = false;
    jugador.semanasContrato = 52 + rnd.nextInt(53);
    jugador.semanasComoSuplente = 0;
    jugador.salarioAnual = calcularSalarioAnual(valor);
    jugador.temporadaUltimoTraspaso = estado.temporada;

    final ganada = reputacionPorTraspaso(
      reputacionActual: rival.reputacion,
      elite: comprador.prestigio >= 85,
    );
    ajustarReputacionRival(rival, ganada);

    resultado.ventas++;
    resultado.noticias.add(
      Noticia(
        semana: estado.semana,
        temporada: estado.temporada,
        texto:
            '${rival.nombre} cierra el traspaso de ${jugador.nick} '
            'a ${comprador.nombre} por ${formatearDinero(valor)}.',
        tipo: TipoNoticia.venta,
      ),
    );
    return true;
  }
  return false;
}

/// Renueva los contratos de los jugadores del rival que están por vencer.
void _renovarContratos(EstadoPartida estado, AgenteRival rival) {
  for (final jugador in carteraDeRival(estado, rival)) {
    if (jugador.equipoId == null) continue;
    if (jugador.semanasContrato > umbralSemanasRenovacion) continue;
    jugador.semanasContrato = 104;
    jugador.salarioAnual = calcularSalarioAnual(_valorDe(jugador));
  }
}

/// Intenta robar a uno de mis representados insatisfechos.
bool _intentarRobo(
  EstadoPartida estado,
  AgenteRival rival,
  Random rnd,
  ResultadoSemanaRivales resultado,
) {
  if (!puedeFicharRival(estado, rival)) return false;
  final objetivos = estado.jugadores.where((j) {
    if (!j.representadoPorMi) return false;
    if (j.enAcademia) return false;
    if (j.satisfaccion >= satisfaccionMinimaRobo) return false;
    if (j.semanasEnfriamientoAgente > 0) return false;
    return true;
  }).toList();
  if (objetivos.isEmpty) return false;

  final jugador = objetivos[rnd.nextInt(objetivos.length)];
  final probabilidad = probabilidadRobo(
    estado: estado,
    rival: rival,
    jugador: jugador,
    rnd: rnd,
  );
  if (rnd.nextDouble() >= probabilidad) return false;

  // El jugador deja mi agencia y firma con el rival.
  jugador.representadoPorMi = false;
  jugador.agenteId = rival.id;
  jugador.semanasRepresentado = 0;
  jugador.semanasEnfriamientoAgente = semanasEnfriamientoCambioAgente;
  jugador.semanasEsperaConvencer = 0;

  resultado.robos++;
  final texto = '${jugador.nick} deja tu agencia y firma con ${rival.nombre}.';
  resultado.noticias.add(
    Noticia(
      semana: estado.semana,
      temporada: estado.temporada,
      texto: texto,
      tipo: TipoNoticia.alerta,
    ),
  );
  resultado.avisosRobo.add(texto);
  return true;
}

// ------------------- REPUTACIÓN -------------------

/// Suma o resta reputación a un rival, siempre entre 0 y 100.
void ajustarReputacionRival(AgenteRival rival, int delta) {
  rival.reputacion = (rival.reputacion + delta).clamp(0, 100);
}

/// Aplica a los rivales la reputación de un título internacional ganado por
/// un equipo. Cada rival con al menos un cliente en ese equipo suma una vez,
/// igual que ocurre con mi agencia.
void aplicarReputacionRivalesPorTitulo(
  EstadoPartida estado,
  String equipoCampeonId, {
  required bool mundial,
}) {
  final idsRivales = <String>{};
  for (final j in estado.jugadores) {
    if (j.representadoPorMi) continue;
    if (j.equipoId != equipoCampeonId) continue;
    final id = j.agenteId;
    if (id == null || id == idMiAgencia) continue;
    idsRivales.add(id);
  }
  if (idsRivales.isEmpty) return;
  final puntos = mundial
      ? efectoCampeonReputacionMundial
      : efectoCampeonReputacionMitad;
  for (final rival in estado.agentesRivales) {
    if (!idsRivales.contains(rival.id)) continue;
    ajustarReputacionRival(rival, puntos);
  }
}

/// Suma reputación al rival que representa a un jugador, si lo hay.
void sumarReputacionAlRivalDeJugador(
  EstadoPartida estado,
  Jugador jugador,
  int delta,
) {
  final rival = rivalDeJugador(estado, jugador);
  if (rival == null) return;
  ajustarReputacionRival(rival, delta);
}

/// Penaliza a los rivales que terminan la temporada con dinero negativo.
void penalizarRivalesArruinados(EstadoPartida estado) {
  for (final rival in estado.agentesRivales) {
    if (rival.dinero < 0) {
      ajustarReputacionRival(rival, -penalizacionRivalArruinado);
    }
  }
}

// ------------------- AGENTE DEL AÑO -------------------

/// Puntuación de un agente para el premio Agente del Año.
class PuntuacionAgente {
  PuntuacionAgente({
    required this.esYo,
    required this.nombre,
    required this.puntos,
    required this.reputacion,
  });

  final bool esYo;
  final String nombre;
  final double puntos;
  final int reputacion;
}

/// Calcula los puntos de cada agente con los pesos del premio:
/// Mundial 15, mitad 8, liga 5, premio individual 3 y MVP 0,5.
///
/// [premiosExtra] permite incluir los premios individuales que se acaban de
/// calcular en la misma ceremonia, antes de añadirlos al estado.
List<PuntuacionAgente> puntuacionesAgenteDelAnio(
  EstadoPartida estado, {
  List<PremioIndividual> premiosExtra = const [],
}) {
  final puntos = <String, double>{};
  const claveYo = idMiAgencia;

  void sumar(String? agenteId, double cantidad) {
    if (agenteId == null) return;
    puntos[agenteId] = (puntos[agenteId] ?? 0) + cantidad;
  }

  String? agenteDe(Jugador j) => j.representadoPorMi ? claveYo : j.agenteId;

  // Títulos de la temporada.
  for (final titulo in estado.palmares.where(
    (r) => r.temporada == estado.temporada,
  )) {
    double valor;
    if (titulo.tipo == TipoCampeon.torneo) {
      valor = (titulo.descripcion == 'Mundial' || titulo.descripcion == 'Major')
          ? puntosTituloMundial
          : puntosTituloMitad;
    } else {
      valor = puntosTituloLiga;
    }
    for (final j in estado.jugadores) {
      if (j.equipoId != titulo.ganadorId) continue;
      sumar(agenteDe(j), valor);
    }
  }

  // Premios individuales de la temporada (los ya guardados y, si se están
  // calculando ahora, los de esta misma ceremonia).
  final premios = [...estado.premios, ...premiosExtra];
  for (final premio in premios) {
    if (premio.temporada != estado.temporada) continue;
    if (premio.categoria == CategoriaPremio.agenteDelAnio) continue;
    final id = premio.jugadorId;
    if (id == null) continue;
    Jugador? jugador;
    for (final j in estado.jugadores) {
      if (j.id == id) {
        jugador = j;
        break;
      }
    }
    if (jugador == null) continue;
    sumar(agenteDe(jugador), 3);
  }

  // MVPs de la temporada.
  for (final j in estado.jugadores) {
    if (j.mvpsTemporada <= 0) continue;
    sumar(agenteDe(j), j.mvpsTemporada * pesoMvpPremio);
  }

  final filas = <PuntuacionAgente>[
    PuntuacionAgente(
      esYo: true,
      nombre: estado.agente.nombre,
      puntos: puntos[claveYo] ?? 0,
      reputacion: estado.agente.reputacion,
    ),
    for (final rival in estado.agentesRivales)
      PuntuacionAgente(
        esYo: false,
        nombre: rival.nombre,
        puntos: puntos[rival.id] ?? 0,
        reputacion: rival.reputacion,
      ),
  ];
  filas.sort((a, b) {
    final porPuntos = b.puntos.compareTo(a.puntos);
    if (porPuntos != 0) return porPuntos;
    final porReputacion = b.reputacion.compareTo(a.reputacion);
    if (porReputacion != 0) return porReputacion;
    return a.nombre.compareTo(b.nombre);
  });
  return filas;
}
