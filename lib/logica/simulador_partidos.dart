// Simula una serie entre dos equipos (al mejor de 3 en liga o de 5 en
// playoffs). Calcula el poder de cada equipo, decide cada mapa, genera las
// estadísticas individuales y actualiza los contadores de los jugadores.
import 'dart:math';

import '../modelos/equipo.dart';
import '../modelos/jugador.dart';
import '../modelos/partido.dart';
import 'formulas.dart';

/// Acumulador temporal de las estadísticas de un jugador durante la serie.
class _Acumulador {
  int eliminaciones = 0;
  int muertes = 0;
  int asistencias = 0;
}

/// Devuelve los titulares de un equipo (los que no son suplentes). Si por
/// alguna razón no hay titulares marcados, usa toda su plantilla.
List<Jugador> titularesDe(Equipo equipo, List<Jugador> jugadores) {
  final todos = jugadores.where((j) => j.equipoId == equipo.id).toList();
  final titulares = todos.where((j) => !j.suplente).toList();
  return titulares.isEmpty ? todos : titulares;
}

/// Alineación disponible de un equipo: titulares no inactivos y, si faltan
/// jugadores, se completa con los suplentes disponibles.
///
/// Nunca falla: si el equipo tiene menos de 5 disponibles juega con los que
/// haya, y si no tiene ninguno devuelve []. Los inactivos no juegan nunca.
List<Jugador> alineacionDe(Equipo equipo, List<Jugador> jugadores) {
  final disponibles = jugadores
      .where((j) => j.equipoId == equipo.id && !j.estaInactivo)
      .toList();
  if (disponibles.isEmpty) return const [];

  final titulares = disponibles.where((j) => !j.suplente).toList();
  final suplentes = disponibles.where((j) => j.suplente).toList();

  final alineacion = <Jugador>[...titulares];
  for (final suplente in suplentes) {
    if (alineacion.length >= 5) break;
    alineacion.add(suplente);
  }
  return alineacion;
}

/// Poder de un equipo: promedio de habilidad de su alineación disponible,
/// ajustado por la moral y por la forma (estrellas) de cada uno. Los
/// suplentes solo cuentan si hacen falta para completar la alineación.
double poderEquipo(Equipo equipo, List<Jugador> jugadores) {
  final titulares = alineacionDe(equipo, jugadores);
  if (titulares.isEmpty) return equipo.prestigio.toDouble();

  final habilidad =
      titulares.map((j) => j.habilidad).reduce((a, b) => a + b) /
      titulares.length;
  final moral =
      titulares.map((j) => j.moral).reduce((a, b) => a + b) / titulares.length;
  final forma =
      titulares
          .map((j) => estrellasDeNotas(j.ultimasNotas))
          .reduce((a, b) => a + b) /
      titulares.length;

  return poderEquipoDesdeNumeros(
        habilidadPromedio: habilidad,
        moralPromedio: moral,
        formaPromedio: forma,
      ) *
      equipo.factorPoder;
}

/// Simula una serie completa y devuelve su resultado.
///
/// - `mapasParaGanar` fija el formato: 1 = Bo1, 2 = Bo3, 3 = Bo5. Si no se
///   indica, se usa el valor de siempre: Bo5 en playoffs y Bo3 en liga.
/// - `esPlayoffs` se conserva como valor por defecto de `mapasParaGanar`.
/// - `rivales` = true → los efectos de moral son mayores (±3 en vez de ±2).
ResultadoSerie simularSerie({
  required int fecha,
  required String etapa,
  required Equipo local,
  required Equipo visitante,
  required List<Jugador> plantillaLocal,
  required List<Jugador> plantillaVisitante,
  bool esPlayoffs = false,
  int? mapasParaGanar,
  required bool rivales,
  required Random rnd,
}) {
  final mapasNecesarios = mapasParaGanar ?? (esPlayoffs ? 3 : 2);
  var mapasLocal = 0;
  var mapasVisitante = 0;

  // Los jugadores inactivos no entran en la alineación ni suman estadísticas.
  final alineacionLocal = alineacionDe(local, plantillaLocal);
  final alineacionVisitante = alineacionDe(visitante, plantillaVisitante);

  final acumulado = <String, _Acumulador>{};
  void acumular(List<Jugador> plantilla, bool ganoMapa) {
    for (final j in plantilla) {
      final acc = acumulado.putIfAbsent(j.id, () => _Acumulador());
      acc.eliminaciones += eliminacionesMapa(
        habilidad: j.habilidad,
        rol: j.rol,
        gano: ganoMapa,
        rnd: rnd,
      );
      acc.muertes += muertesMapa(rol: j.rol, gano: ganoMapa, rnd: rnd);
      acc.asistencias += asistenciasMapa(
        habilidad: j.habilidad,
        rol: j.rol,
        gano: ganoMapa,
        rnd: rnd,
      );
    }
  }

  // Se juegan mapas hasta que uno llegue a los necesarios.
  while (mapasLocal < mapasNecesarios && mapasVisitante < mapasNecesarios) {
    final poderLocal = poderEquipo(local, alineacionLocal);
    final poderVisitante = poderEquipo(visitante, alineacionVisitante);
    final probLocal = probVictoria(poderLocal, poderVisitante);
    final ganoLocal = rnd.nextDouble() < probLocal;
    if (ganoLocal) {
      mapasLocal++;
    } else {
      mapasVisitante++;
    }
    acumular(alineacionLocal, ganoLocal);
    acumular(alineacionVisitante, !ganoLocal);
  }

  final ganoElLocal = mapasLocal > mapasVisitante;
  final ganador = ganoElLocal ? local : visitante;
  final plantillaGanadora = ganoElLocal ? alineacionLocal : alineacionVisitante;
  final plantillaPerdedora = ganoElLocal
      ? alineacionVisitante
      : alineacionLocal;

  // Notas individuales (solo de los que jugaron).
  final notas = <String, double>{};
  _aplicarEstadisticas(
    plantilla: plantillaGanadora,
    gano: true,
    acumulado: acumulado,
    notas: notas,
    rnd: rnd,
    deltaMoral: rivales ? 3 : 2,
  );
  _aplicarEstadisticas(
    plantilla: plantillaPerdedora,
    gano: false,
    acumulado: acumulado,
    notas: notas,
    rnd: rnd,
    deltaMoral: -(rivales ? 3 : 2),
  );

  // MVP de la serie: la mejor nota del equipo ganador.
  String? mvpId;
  var mejorNota = -1.0;
  for (final j in plantillaGanadora) {
    final nota = notas[j.id] ?? 0;
    if (nota > mejorNota) {
      mejorNota = nota;
      mvpId = j.id;
    }
  }
  if (mvpId != null) {
    for (final j in plantillaGanadora) {
      if (j.id == mvpId) {
        j.mvpsTemporada++;
        j.mvpsCarrera++;
      }
    }
  }

  return ResultadoSerie(
    fecha: fecha,
    etapa: etapa,
    localId: local.id,
    visitanteId: visitante.id,
    mapasLocal: mapasLocal,
    mapasVisitante: mapasVisitante,
    ganadorId: ganador.id,
  );
}

/// Simula un enfrentamiento entre dos equipos a partir de la lista completa
/// de jugadores, filtrando la plantilla de cada equipo. Helper compartido
/// por la liga y por los torneos internacionales.
ResultadoSerie? simularEnfrentamiento({
  required Equipo local,
  required Equipo visitante,
  required List<Jugador> plantillas,
  required String etapa,
  required int mapasParaGanar,
  required bool rivales,
  required Random rnd,
  int fecha = 0,
}) {
  return simularSerie(
    fecha: fecha,
    etapa: etapa,
    local: local,
    visitante: visitante,
    plantillaLocal: alineacionDe(local, plantillas),
    plantillaVisitante: alineacionDe(visitante, plantillas),
    esPlayoffs: mapasParaGanar >= 3,
    mapasParaGanar: mapasParaGanar,
    rivales: rivales,
    rnd: rnd,
  );
}

/// Actualiza contadores, notas y moral de toda una plantilla.
void _aplicarEstadisticas({
  required List<Jugador> plantilla,
  required bool gano,
  required Map<String, _Acumulador> acumulado,
  required Map<String, double> notas,
  required Random rnd,
  required int deltaMoral,
}) {
  for (final j in plantilla) {
    final acc = acumulado[j.id] ?? _Acumulador();
    final azar = -2 + rnd.nextDouble() * 4;
    final nota = notaJugador(habilidad: j.habilidad, gano: gano, azar: azar);
    notas[j.id] = nota;

    j.partidasTemporada++;
    if (gano) j.victoriasTemporada++;
    j.notaTotalTemporada += nota;
    j.eliminacionesTemporada += acc.eliminaciones;
    j.muertesTemporada += acc.muertes;
    j.asistenciasTemporada += acc.asistencias;
    j.eliminacionesCarrera += acc.eliminaciones;
    j.muertesCarrera += acc.muertes;
    j.asistenciasCarrera += acc.asistencias;

    j.ultimasNotas.add(nota);
    if (j.ultimasNotas.length > partidosForma) {
      j.ultimasNotas.removeAt(0);
    }

    j.moral = (j.moral + deltaMoral).clamp(0, 100);
  }
}
