// Lógica de los torneos internacionales: clasificación, grupos, brackets de
// eliminación directa, reparto de premios y efectos de ser campeón.
//
// El Torneo de Mitad de Temporada (semanas 21–22) es eliminación directa Bo5.
// El Mundial (semanas 43–46) empieza con grupos Bo1 y sigue con eliminación
// directa Bo5. El bracket se adapta al número de clasificados: si no es
// potencia de 2, los de mayor prestigio reciben bye. La final se juega como
// muy tarde en la semana 46, aunque sobren semanas (p. ej. CS2 con 8 equipos).
import 'dart:math';

import '../modelos/agente.dart';
import '../modelos/competicion.dart';
import '../modelos/equipo.dart';
import '../modelos/estado_partida.dart';
import '../modelos/juego.dart';
import '../modelos/jugador.dart';
import '../modelos/partido.dart';
import '../modelos/torneo.dart';
import 'formulas.dart';
import 'satisfaccion.dart' as sat;
import 'simulador_partidos.dart';

// ------------------- CLASIFICACIÓN -------------------

/// Campeones del Split 1 de 1ª División de cada región del videojuego.
List<String> clasificadosMitad(EstadoPartida estado, Juego juego) {
  final resultado = <String>[];
  for (final comp in estado.competiciones.where(
    (c) => c.juego == juego && c.division == 1,
  )) {
    final campeon = comp.campeonSplit(1);
    if (campeon != null) {
      resultado.add(campeon);
    } else {
      final tabla = comp.tablaSplit(1);
      if (tabla.isNotEmpty) resultado.add(tabla.first.equipoId);
    }
  }
  return resultado;
}

/// Los 2 mejores de cada región de 1ª División por puntos sumados de ambos
/// splits (Split 1 + Split 2).
List<String> clasificadosMundial(EstadoPartida estado, Juego juego) {
  final resultado = <String>[];
  for (final comp in estado.competiciones.where(
    (c) => c.juego == juego && c.division == 1,
  )) {
    resultado.addAll(tablaSumada(comp).take(2));
  }
  return resultado;
}

/// Tabla de posiciones sumando los dos splits (puntos, diferencia de mapas).
List<String> tablaSumada(Competicion comp) {
  final puntos = <String, int>{for (final id in comp.equipoIds) id: 0};
  final dif = <String, int>{for (final id in comp.equipoIds) id: 0};
  final aFavor = <String, int>{for (final id in comp.equipoIds) id: 0};

  void sumar(ResultadoSerie r) {
    if (!puntos.containsKey(r.localId) || !puntos.containsKey(r.visitanteId)) {
      return;
    }
    if (r.ganadorId == r.localId) {
      puntos[r.localId] = puntos[r.localId]! + puntosVictoria;
    } else {
      puntos[r.visitanteId] = puntos[r.visitanteId]! + puntosVictoria;
    }
    dif[r.localId] = dif[r.localId]! + (r.mapasLocal - r.mapasVisitante);
    dif[r.visitanteId] =
        dif[r.visitanteId]! + (r.mapasVisitante - r.mapasLocal);
    aFavor[r.localId] = aFavor[r.localId]! + r.mapasLocal;
    aFavor[r.visitanteId] = aFavor[r.visitanteId]! + r.mapasVisitante;
  }

  for (final r in comp.resultadosSplit1) {
    sumar(r);
  }
  for (final r in comp.resultadosSplit2) {
    sumar(r);
  }

  return comp.equipoIds.toList()..sort((a, b) {
    final porPuntos = puntos[b]!.compareTo(puntos[a]!);
    if (porPuntos != 0) return porPuntos;
    final porDif = dif[b]!.compareTo(dif[a]!);
    if (porDif != 0) return porDif;
    return aFavor[b]!.compareTo(aFavor[a]!);
  });
}

// ------------------- CREACIÓN -------------------

/// Crea el Torneo de Mitad de Temporada de un videojuego.
Torneo crearTorneoMitad(
  EstadoPartida estado,
  Juego juego,
  Map<String, Equipo> equipos,
) {
  final participantes = _ordenarPorPrestigio(
    clasificadosMitad(estado, juego),
    equipos,
  );
  return Torneo(
    id: 'mitad_${juego.name}_${estado.temporada}',
    tipo: TipoTorneo.mitad,
    juego: juego,
    temporada: estado.temporada,
    nombre: 'Torneo de Mitad de Temporada',
    participantes: participantes,
  );
}

/// Crea el Mundial (o Major en CS2) de un videojuego, con sus grupos.
Torneo crearTorneoMundial(
  EstadoPartida estado,
  Juego juego,
  Map<String, Equipo> equipos,
) {
  final participantes = _ordenarPorPrestigio(
    clasificadosMundial(estado, juego),
    equipos,
  );
  return Torneo(
    id: 'mundial_${juego.name}_${estado.temporada}',
    tipo: TipoTorneo.mundial,
    juego: juego,
    temporada: estado.temporada,
    nombre: juego == Juego.cs2 ? 'Major' : 'Mundial',
    participantes: participantes,
    grupos: _gruposDesdeParticipantes(participantes),
  );
}

/// Reparte los participantes en grupos de 3–4 por siembra (serpiente).
Map<String, List<String>> _gruposDesdeParticipantes(List<String> ids) {
  final n = ids.length;
  if (n < 2) return <String, List<String>>{};
  final numGrupos = n <= 8 ? 2 : (n <= 12 ? 3 : 4);
  final grupos = <String, List<String>>{
    for (var i = 0; i < numGrupos; i++) String.fromCharCode(65 + i): <String>[],
  };
  for (var i = 0; i < n; i++) {
    final vuelta = i ~/ numGrupos;
    final posicion = vuelta.isEven
        ? i % numGrupos
        : numGrupos - 1 - (i % numGrupos);
    grupos[String.fromCharCode(65 + posicion)]!.add(ids[i]);
  }
  return grupos;
}

// ------------------- BRACKET -------------------

/// Construye el cuadro de la primera ronda de eliminación directa.
///
/// Devuelve pares (local, visitante); un visitante `null` significa que el
/// local recibe bye. Si el número de equipos no es potencia de 2, los de
/// mayor prestigio (los primeros de la lista) reciben bye.
List<(String, String?)> construirBracket(List<String> idsOrdenados) {
  final n = idsOrdenados.length;
  if (n == 0) return const [];
  var potencia = 1;
  while (potencia < n) {
    potencia *= 2;
  }
  final byes = potencia - n;
  final cruces = <(String, String?)>[];
  for (var i = 0; i < byes && i < n; i++) {
    cruces.add((idsOrdenados[i], null));
  }
  final resto = idsOrdenados.sublist(byes);
  var lo = 0;
  var hi = resto.length - 1;
  while (lo < hi) {
    cruces.add((resto[lo], resto[hi]));
    lo++;
    hi--;
  }
  if (lo == hi && hi >= 0 && hi < resto.length) {
    cruces.add((resto[lo], null));
  }
  return cruces;
}

/// Empareja a los supervivientes de una ronda: el mejor recibe bye si el
/// número es impar y el resto se cruza en orden.
List<(String, String?)> _emparejar(List<String> vivos) {
  if (vivos.isEmpty) return const [];
  if (vivos.length == 1) return [(vivos[0], null)];
  final cruces = <(String, String?)>[];
  var inicio = 0;
  if (vivos.length.isOdd) {
    cruces.add((vivos[0], null));
    inicio = 1;
  }
  for (var i = inicio; i + 1 < vivos.length; i += 2) {
    cruces.add((vivos[i], vivos[i + 1]));
  }
  return cruces;
}

/// Nombre de la ronda según cuántos equipos siguen vivos.
String _nombreRonda(int equipos) {
  switch (equipos) {
    case 2:
      return 'Final';
    case 4:
      return 'Semifinal';
    case 8:
      return 'Cuartos';
    case 16:
      return 'Octavos';
    default:
      return 'Ronda de $equipos';
  }
}

// ------------------- AVANCE DE TORNEOS -------------------

/// Avanza el Torneo de Mitad de Temporada en la semana indicada.
/// Semana 21: se juega todo hasta dejar 2 finalistas. Semana 22: la final.
void avanzarTorneoMitad(
  Torneo torneo, {
  required Map<String, Equipo> equipos,
  required List<Jugador> jugadores,
  required Random rnd,
  required int semana,
}) {
  if (semana <= 21) {
    var seguridad = 8;
    while (_vivosEliminacion(torneo).length > 2 && seguridad-- > 0) {
      _jugarRondaEliminacion(
        torneo,
        equipos: equipos,
        jugadores: jugadores,
        rnd: rnd,
      );
    }
  } else if (_vivosEliminacion(torneo).length > 1) {
    _jugarRondaEliminacion(
      torneo,
      equipos: equipos,
      jugadores: jugadores,
      rnd: rnd,
    );
  }
}

/// Avanza el Mundial en la semana indicada. Semana 43: grupos (Bo1).
/// Semanas 44–46: una ronda de eliminación por semana; en la 46 se juega
/// todo lo que falte para que la final nunca pase de la semana 46.
void avanzarTorneoMundial(
  Torneo torneo, {
  required Map<String, Equipo> equipos,
  required List<Jugador> jugadores,
  required Random rnd,
  required int semana,
}) {
  if (semana <= 43 || !torneo.gruposJugados) {
    _jugarGrupos(torneo, equipos: equipos, jugadores: jugadores, rnd: rnd);
    if (semana <= 43) return;
  }

  if (_vivosEliminacion(torneo).length <= 1) return;

  if (semana >= 46) {
    var seguridad = 4;
    while (_vivosEliminacion(torneo).length > 1 && seguridad-- > 0) {
      _jugarRondaEliminacion(
        torneo,
        equipos: equipos,
        jugadores: jugadores,
        rnd: rnd,
      );
    }
  } else {
    _jugarRondaEliminacion(
      torneo,
      equipos: equipos,
      jugadores: jugadores,
      rnd: rnd,
    );
  }
}

/// ¿El torneo ya tiene campeón?
bool torneoTerminado(Torneo torneo) => torneo.campeonId != null;

// ------------------- FASES INTERNAS -------------------

/// Juega todos los cruces de la fase de grupos (todos contra todos, Bo1).
void _jugarGrupos(
  Torneo torneo, {
  required Map<String, Equipo> equipos,
  required List<Jugador> jugadores,
  required Random rnd,
}) {
  if (torneo.gruposJugados || torneo.grupos.isEmpty) return;
  final resultados = <ResultadoSerie>[];
  for (final entrada in torneo.grupos.entries) {
    final ids = entrada.value;
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final r = _serie(
          localId: ids[i],
          visitanteId: ids[j],
          etapa: 'Grupo ${entrada.key}',
          mapasParaGanar: 1,
          equipos: equipos,
          jugadores: jugadores,
          rnd: rnd,
        );
        if (r != null) resultados.add(r);
      }
    }
  }
  if (resultados.isNotEmpty) torneo.rondas.add(resultados);
}

/// Juega la siguiente ronda de eliminación directa (Bo5).
void _jugarRondaEliminacion(
  Torneo torneo, {
  required Map<String, Equipo> equipos,
  required List<Jugador> jugadores,
  required Random rnd,
}) {
  final vivos = _ordenarPorPrestigio(_vivosEliminacion(torneo), equipos);
  if (vivos.length <= 1) return;

  final cruces = torneo.rondasEliminacion.isEmpty
      ? construirBracket(vivos)
      : _emparejar(vivos);
  final etapa = _nombreRonda(vivos.length);
  final resultados = <ResultadoSerie>[];
  for (final cruce in cruces) {
    final rival = cruce.$2;
    if (rival == null) continue; // El local pasa directamente (bye).
    final r = _serie(
      localId: cruce.$1,
      visitanteId: rival,
      etapa: etapa,
      mapasParaGanar: 3,
      equipos: equipos,
      jugadores: jugadores,
      rnd: rnd,
    );
    if (r != null) resultados.add(r);
  }
  if (resultados.isNotEmpty) torneo.rondas.add(resultados);
}

/// Equipos que siguen vivos en la eliminación directa.
List<String> _vivosEliminacion(Torneo torneo) {
  var vivos = torneo.grupos.isNotEmpty
      ? _clasificadosDeGrupos(torneo)
      : List<String>.from(torneo.participantes);

  for (final ronda in torneo.rondasEliminacion) {
    final participantes = <String>{};
    final ganadores = <String>{};
    for (final r in ronda) {
      participantes.add(r.localId);
      participantes.add(r.visitanteId);
      ganadores.add(r.ganadorId);
    }
    // Quien ganó sigue; quien no jugó (bye) también sigue.
    vivos = [
      for (final id in vivos)
        if (ganadores.contains(id) || !participantes.contains(id)) id,
    ];
  }
  return vivos;
}

/// Una fila de la tabla de un grupo de un torneo.
class FilaGrupoTorneo {
  const FilaGrupoTorneo({
    required this.equipoId,
    required this.puntos,
    required this.diferenciaMapas,
  });

  final String equipoId;
  final int puntos;
  final int diferenciaMapas;
}

/// Tabla ordenada de un grupo (puntos y diferencia de mapas).
///
/// La usan tanto la clasificación del torneo como la pantalla de Torneos:
/// antes cada una repetía el mismo cálculo y podían dar resultados distintos
/// (sección 5 de la auditoría).
List<FilaGrupoTorneo> tablaGrupo(Torneo torneo, String grupo) {
  final ids = torneo.grupos[grupo] ?? const <String>[];
  final etapa = 'Grupo $grupo';
  final puntos = <String, int>{for (final id in ids) id: 0};
  final dif = <String, int>{for (final id in ids) id: 0};

  for (final r in torneo.todosLosResultados.where((r) => r.etapa == etapa)) {
    if (!puntos.containsKey(r.localId) || !puntos.containsKey(r.visitanteId)) {
      continue;
    }
    if (r.ganadorId == r.localId) {
      puntos[r.localId] = puntos[r.localId]! + puntosVictoria;
    } else {
      puntos[r.visitanteId] = puntos[r.visitanteId]! + puntosVictoria;
    }
    dif[r.localId] = dif[r.localId]! + (r.mapasLocal - r.mapasVisitante);
    dif[r.visitanteId] =
        dif[r.visitanteId]! + (r.mapasVisitante - r.mapasLocal);
  }

  final filas =
      [
        for (final id in ids)
          FilaGrupoTorneo(
            equipoId: id,
            puntos: puntos[id]!,
            diferenciaMapas: dif[id]!,
          ),
      ]..sort((a, b) {
        final porPuntos = b.puntos.compareTo(a.puntos);
        if (porPuntos != 0) return porPuntos;
        return b.diferenciaMapas.compareTo(a.diferenciaMapas);
      });
  return filas;
}

/// Los 2 mejores de cada grupo por puntos y diferencia de mapas.
List<String> _clasificadosDeGrupos(Torneo torneo) {
  final clasificados = <String>[];
  for (final grupo in torneo.grupos.keys) {
    clasificados.addAll(
      tablaGrupo(torneo, grupo).take(2).map((fila) => fila.equipoId),
    );
  }
  return clasificados;
}

/// Simula un cruce entre dos equipos por su id.
ResultadoSerie? _serie({
  required String localId,
  required String visitanteId,
  required String etapa,
  required int mapasParaGanar,
  required Map<String, Equipo> equipos,
  required List<Jugador> jugadores,
  required Random rnd,
}) {
  final local = equipos[localId];
  final visitante = equipos[visitanteId];
  if (local == null || visitante == null) return null;
  final rivales =
      local.rivales.contains(visitante.id) ||
      visitante.rivales.contains(local.id);
  return simularEnfrentamiento(
    local: local,
    visitante: visitante,
    plantillas: jugadores,
    etapa: etapa,
    mapasParaGanar: mapasParaGanar,
    rivales: rivales,
    rnd: rnd,
  );
}

/// Ordena una lista de ids por prestigio (mayor primero).
List<String> _ordenarPorPrestigio(
  List<String> ids,
  Map<String, Equipo> equipos,
) {
  final copia = List<String>.from(ids);
  copia.sort((a, b) {
    final pa = equipos[a]?.prestigio ?? 0;
    final pb = equipos[b]?.prestigio ?? 0;
    return pb.compareTo(pa);
  });
  return copia;
}

// ------------------- PREMIOS Y EFECTOS -------------------

/// Calcula el reparto de premios de un torneo (equipo -> dinero) según su
/// colocación, sin aplicarlo a ningún presupuesto. Sirve también para la
/// interfaz, que muestra cuánto se llevó cada equipo.
Map<String, int> distribucionPremios(Torneo torneo) {
  final distribucion = <String, int>{};
  final elim = torneo.rondasEliminacion;
  if (elim.isEmpty || !torneo.finalJugada) return distribucion;
  final finalRonda = elim.last;

  final esMitad = torneo.tipo == TipoTorneo.mitad;
  final total = esMitad ? premioMitadTotal : premioMundialTotal;
  final pctCampeon = esMitad ? premioMitadCampeon : premioMundialCampeon;
  final pctFinalista = esMitad ? premioMitadFinalista : premioMundialFinalista;
  final pctSemi = esMitad ? premioMitadSemifinal : premioMundialSemifinal;

  distribucion[finalRonda.last.ganadorId] = (total * pctCampeon).round();
  distribucion[finalRonda.last.perdedorId] = (total * pctFinalista).round();

  if (elim.length >= 2) {
    for (final r in elim[elim.length - 2]) {
      distribucion[r.perdedorId] = (total * pctSemi).round();
    }
  }
  if (!esMitad && elim.length >= 3) {
    for (final r in elim[elim.length - 3]) {
      distribucion[r.perdedorId] = (total * premioMundialCuartos).round();
    }
  }

  return distribucion;
}

/// Reparte el dinero del torneo entre los equipos según su colocación.
/// Devuelve el mapa de equipo -> premio otorgado.
Map<String, int> repartirPremios(Torneo torneo, Map<String, Equipo> equipos) {
  final distribucion = distribucionPremios(torneo);
  for (final entrada in distribucion.entries) {
    final equipo = equipos[entrada.key];
    if (equipo != null) equipo.presupuesto += entrada.value;
  }
  return distribucion;
}

/// Aplica los efectos de ser campeón internacional a mis representados del
/// equipo campeón: moral +15, valor ×1,10 y reputación +2 (mitad) / +5
/// (Mundial). Devuelve la lista de jugadores premiados.
List<Jugador> aplicarEfectosCampeon(
  Torneo torneo,
  List<Jugador> jugadores,
  Agente agente,
) {
  final campeonId = torneo.campeonId;
  if (campeonId == null) return const [];

  final premiados = <Jugador>[];
  for (final j in jugadores) {
    if (j.representadoPorMi && j.equipoId == campeonId) {
      j.moral = (j.moral + efectoCampeonMoral).clamp(0, 100);
      j.multiplicadorValor = (j.multiplicadorValor * efectoCampeonMultiplicador)
          .clamp(multiplicadorValorMinimo, multiplicadorValorMaximo);
      sat.aplicarEfectoTitulo(
        j,
        mundial: torneo.tipo == TipoTorneo.mundial,
      );
      premiados.add(j);
    }
  }

  if (premiados.isNotEmpty) {
    final reputacion = torneo.tipo == TipoTorneo.mitad
        ? efectoCampeonReputacionMitad
        : efectoCampeonReputacionMundial;
    agente.reputacion = min(100, agente.reputacion + reputacion);
  }
  return premiados;
}
