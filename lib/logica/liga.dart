// Lógica de una liga: genera el calendario (round-robin), simula cada
// fecha y juega los playoffs. No guarda nada: el calendario se deriva del
// orden estable de los equipos y los resultados se guardan en la liga.
import 'dart:math';

import '../modelos/competicion.dart';
import '../modelos/equipo.dart';
import '../modelos/jugador.dart';
import '../modelos/partido.dart';
import 'simulador_partidos.dart';

/// Genera un calendario round-robin de ida y vuelta.
///
/// Para 8 equipos produce 14 fechas de 4 series cada una. Devuelve una
/// lista de fechas y, dentro de cada una, pares (local, visitante).
List<List<(String, String)>> generarFechas(List<String> equipoIds) {
  if (equipoIds.length < 2) return const [];

  final equipos = List<String>.from(equipoIds);
  // Si el número es impar, se añade un "descanso" y se filtra después.
  if (equipos.length.isOdd) equipos.add('__descanso__');

  final n = equipos.length;
  final primeraVuelta = <List<(String, String)>>[];

  for (var ronda = 0; ronda < n - 1; ronda++) {
    final fecha = <(String, String)>[];
    for (var i = 0; i < n ~/ 2; i++) {
      final a = equipos[i];
      final b = equipos[n - 1 - i];
      if (a == '__descanso__' || b == '__descanso__') continue;
      // Alterno la localía para repartirla de forma más justa.
      fecha.add(ronda.isEven ? (a, b) : (b, a));
    }
    primeraVuelta.add(fecha);

    // Rotación manteniendo fijo el primero.
    final ultimo = equipos.removeLast();
    equipos.insert(1, ultimo);
  }

  // Segunda vuelta: se intercambian local y visitante.
  final segundaVuelta = primeraVuelta
      .map((fecha) => fecha.map((s) => (s.$2, s.$1)).toList())
      .toList();

  return [...primeraVuelta, ...segundaVuelta];
}

/// Simula las series de una fecha de liga y guarda los resultados.
void simularFecha(
  Competicion competicion,
  int split,
  int fecha,
  Map<String, Equipo> equipos,
  List<Jugador> jugadores,
  Random rnd,
) {
  final fechas = generarFechas(competicion.equipoIds);
  if (fecha < 1 || fecha > fechas.length) return;

  final etapa = 'Liga Split $split';
  final resultados = <ResultadoSerie>[];
  for (final serie in fechas[fecha - 1]) {
    final resultado = _simularEnfrentamiento(
      competicion: competicion,
      equipos: equipos,
      jugadores: jugadores,
      localId: serie.$1,
      visitanteId: serie.$2,
      fecha: fecha,
      etapa: etapa,
      esPlayoffs: false,
      rnd: rnd,
    );
    if (resultado != null) resultados.add(resultado);
  }
  competicion.agregarResultados(split, resultados);
}

/// Juega la siguiente ronda de playoffs de un split.
///
/// La primera llamada juega las semifinales (1º vs 4º y 2º vs 3º); la
/// siguiente juega la final entre los dos ganadores.
void jugarPlayoffs(
  Competicion competicion,
  int split,
  Map<String, Equipo> equipos,
  List<Jugador> jugadores,
  Random rnd,
) {
  final tabla = competicion.tablaSplit(split);
  if (tabla.length < 4) return;

  final playoffs = competicion.resultadosPlayoffsDe(split);
  final etapa = 'Playoffs Split $split';

  if (playoffs.isEmpty) {
    // Semifinales: 1º vs 4º y 2º vs 3º.
    final semis = <ResultadoSerie>[];
    final cruces = [
      (tabla[0].equipoId, tabla[3].equipoId),
      (tabla[1].equipoId, tabla[2].equipoId),
    ];
    for (final cruce in cruces) {
      final resultado = _simularEnfrentamiento(
        competicion: competicion,
        equipos: equipos,
        jugadores: jugadores,
        localId: cruce.$1,
        visitanteId: cruce.$2,
        fecha: 0,
        etapa: etapa,
        esPlayoffs: true,
        rnd: rnd,
      );
      if (resultado != null) semis.add(resultado);
    }
    competicion.agregarPlayoffs(split, semis);
  } else if (playoffs.length == 2) {
    // Final entre los dos ganadores.
    final ganadores = playoffs.map((r) => r.ganadorId).toList();
    final finalSerie = _simularEnfrentamiento(
      competicion: competicion,
      equipos: equipos,
      jugadores: jugadores,
      localId: ganadores[0],
      visitanteId: ganadores[1],
      fecha: 0,
      etapa: etapa,
      esPlayoffs: true,
      rnd: rnd,
    );
    if (finalSerie != null) competicion.agregarPlayoffs(split, [finalSerie]);
  }
}

/// Devuelve el campeón de los playoffs de un split (o null).
String? campeonDe(Competicion competicion, int split) =>
    competicion.campeonSplit(split);

/// Simula un enfrentamiento entre dos equipos por sus ids.
ResultadoSerie? _simularEnfrentamiento({
  required Competicion competicion,
  required Map<String, Equipo> equipos,
  required List<Jugador> jugadores,
  required String localId,
  required String visitanteId,
  required int fecha,
  required String etapa,
  required bool esPlayoffs,
  required Random rnd,
}) {
  final local = equipos[localId];
  final visitante = equipos[visitanteId];
  if (local == null || visitante == null) return null;

  final sonRivales =
      local.rivales.contains(visitante.id) ||
      visitante.rivales.contains(local.id);

  return simularEnfrentamiento(
    local: local,
    visitante: visitante,
    plantillas: jugadores,
    etapa: etapa,
    mapasParaGanar: esPlayoffs ? 3 : 2,
    rivales: sonRivales,
    rnd: rnd,
    fecha: fecha,
  );
}
