// Premios individuales de fin de temporada: Jugador del Año, Máximo
// Eliminador, Revelación del Año, Mejor Equipo Ideal y Agente del Año.
//
// Se entregan por videojuego, salvo el Agente del Año, que es único para la
// temporada. Solo optan a premio los jugadores con al menos `minimoSeriesPremio`
// series jugadas.
import 'dart:math';

import '../modelos/estado_partida.dart';
import '../modelos/historial.dart';
import '../modelos/juego.dart';
import '../modelos/jugador.dart';
import 'formulas.dart';

/// Roles que cuentan para el Máximo Eliminador en LoL y Dota 2.
const Set<String> _rolesEliminadoresLolDota = {'Carry', 'ADC', 'Mid'};

/// Calcula los premios individuales de un videojuego.
///
/// `puntosTitulosPorJugador` trae los puntos de títulos ya ponderados
/// (Mundial 15, mitad de temporada 8, liga 5) para el puntaje del Año.
List<PremioIndividual> calcularPremios(
  EstadoPartida estado,
  Juego juego,
  Map<String, double> puntosTitulosPorJugador,
) {
  final temporada = estado.temporada;
  final premios = <PremioIndividual>[];
  final jugadores = estado.jugadores.where((j) => j.juego == juego).toList();
  final elegibles = jugadores
      .where((j) => j.partidasTemporada >= minimoSeriesPremio)
      .toList();
  if (elegibles.isEmpty) return premios;

  // --- Jugador del Año ---
  final porAnio = List<Jugador>.from(elegibles)
    ..sort(
      (a, b) => _puntajeAnio(
        b,
        puntosTitulosPorJugador,
      ).compareTo(_puntajeAnio(a, puntosTitulosPorJugador)),
    );
  final jugadorDelAnio = porAnio.first;
  premios.add(
    PremioIndividual(
      temporada: temporada,
      juego: juego,
      categoria: CategoriaPremio.jugadorDelAnio,
      jugadorId: jugadorDelAnio.id,
      nombreJugador: jugadorDelAnio.nick,
      detalle:
          '${jugadorDelAnio.nick} (${jugadorDelAnio.rol}) · '
          'nota ${jugadorDelAnio.promedioNota.toStringAsFixed(1)} · '
          '${jugadorDelAnio.mvpsTemporada} MVP',
    ),
  );

  // --- Revelación del Año ---
  final jovenes = elegibles.where((j) => j.edad <= 20).toList()
    ..sort(
      (a, b) => _puntajeAnio(
        b,
        puntosTitulosPorJugador,
      ).compareTo(_puntajeAnio(a, puntosTitulosPorJugador)),
    );
  if (jovenes.isNotEmpty) {
    final revelacion = jovenes.first;
    premios.add(
      PremioIndividual(
        temporada: temporada,
        juego: juego,
        categoria: CategoriaPremio.revelacion,
        jugadorId: revelacion.id,
        nombreJugador: revelacion.nick,
        detalle:
            '${revelacion.nick} (${revelacion.edad} años) · '
            'nota ${revelacion.promedioNota.toStringAsFixed(1)}',
      ),
    );
  }

  // --- Máximo Eliminador ---
  final porKills =
      elegibles.where((j) => _cuentaParaEliminaciones(j, juego)).toList()..sort(
        (a, b) => b.eliminacionesTemporada.compareTo(a.eliminacionesTemporada),
      );
  if (porKills.isNotEmpty) {
    final killer = porKills.first;
    premios.add(
      PremioIndividual(
        temporada: temporada,
        juego: juego,
        categoria: CategoriaPremio.maximoEliminador,
        jugadorId: killer.id,
        nombreJugador: killer.nick,
        detalle:
            '${killer.nick} (${killer.rol}) · '
            '${killer.eliminacionesTemporada} eliminaciones',
      ),
    );
  }

  // --- Mejor Equipo Ideal (un premio por videojuego con los 5 roles) ---
  final ideal = <String, Jugador>{};
  for (final rol in juego.roles) {
    final delRol = elegibles.where((j) => j.rol == rol).toList()
      ..sort((a, b) => b.promedioNota.compareTo(a.promedioNota));
    if (delRol.isNotEmpty) ideal[rol] = delRol.first;
  }
  if (ideal.isNotEmpty) {
    final detalle = juego.roles
        .where(ideal.containsKey)
        .map((rol) => '$rol: ${ideal[rol]!.nick}')
        .join(' · ');
    premios.add(
      PremioIndividual(
        temporada: temporada,
        juego: juego,
        categoria: CategoriaPremio.equipoIdeal,
        detalle: detalle,
      ),
    );
  }

  return premios;
}

/// Calcula el Agente del Año: lo gano si el total de títulos de mis
/// representados en la temporada supera el de cualquier equipo.
PremioIndividual? calcularAgenteDelAnio(EstadoPartida estado) {
  final temporada = estado.temporada;
  final titulos = estado.palmares.where((r) => r.temporada == temporada);

  final misRepresentadosPorEquipo = <String, bool>{};
  for (final j in estado.jugadores) {
    if (j.representadoPorMi && j.equipoId != null) {
      misRepresentadosPorEquipo[j.equipoId!] = true;
    }
  }

  final misTitulos = titulos
      .where((r) => misRepresentadosPorEquipo[r.ganadorId] == true)
      .length;

  final porEquipo = <String, int>{};
  for (final r in titulos) {
    porEquipo[r.ganadorId] = (porEquipo[r.ganadorId] ?? 0) + 1;
  }
  final mejorEquipo = porEquipo.values.isEmpty
      ? 0
      : porEquipo.values.reduce((a, b) => a > b ? a : b);

  if (misTitulos <= mejorEquipo || misTitulos == 0) return null;

  return PremioIndividual(
    temporada: temporada,
    categoria: CategoriaPremio.agenteDelAnio,
    nombreAgente: estado.agente.nombre,
    detalle: 'Tu agencia sumó $misTitulos títulos esta temporada.',
  );
}

/// Aplica los efectos de los premios a mis representados: valor +15%,
/// moral +20 y reputación +3 por premiado. El Agente del Año da +5 extra.
void aplicarEfectosPremios(
  EstadoPartida estado,
  List<PremioIndividual> premios,
) {
  for (final premio in premios) {
    if (premio.categoria == CategoriaPremio.agenteDelAnio) {
      estado.agente.reputacion = min(
        100,
        estado.agente.reputacion + reputacionAgenteDelAnio,
      );
      continue;
    }
    final id = premio.jugadorId;
    if (id == null) continue;
    final jugador = _jugadorPorId(estado, id);
    if (jugador == null || !jugador.representadoPorMi) continue;
    jugador.moral = (jugador.moral + efectoPremioMoral).clamp(0, 100);
    jugador.multiplicadorValor =
        (jugador.multiplicadorValor * efectoPremioMultiplicador).clamp(
          multiplicadorValorMinimo,
          multiplicadorValorMaximo,
        );
    estado.agente.reputacion = min(
      100,
      estado.agente.reputacion + efectoPremioReputacion,
    );
  }
}

/// Puntaje del Jugador del Año: nota × 10 + títulos + MVPs × 0,5.
double _puntajeAnio(Jugador j, Map<String, double> puntosTitulos) {
  return j.promedioNota * pesoNotaPremio +
      (puntosTitulos[j.id] ?? 0) +
      j.mvpsTemporada * pesoMvpPremio;
}

/// En LoL y Dota 2 solo cuentan para eliminaciones Carry, ADC y Mid.
bool _cuentaParaEliminaciones(Jugador j, Juego juego) {
  if (juego == Juego.lol || juego == Juego.dota2) {
    return _rolesEliminadoresLolDota.contains(j.rol);
  }
  return true;
}

Jugador? _jugadorPorId(EstadoPartida estado, String id) {
  for (final j in estado.jugadores) {
    if (j.id == id) return j;
  }
  return null;
}
