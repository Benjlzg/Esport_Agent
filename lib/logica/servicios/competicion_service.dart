// Servicio de competición (corrección I11): ligas, playoffs, torneos,
// palmarés y premios individuales. `MotorJuego` delega en él.
import 'dart:math';

import '../../modelos/competicion.dart';
import '../../modelos/equipo.dart';
import '../../modelos/historial.dart';
import '../../modelos/juego.dart';
import '../../modelos/noticia.dart';
import '../../modelos/partido.dart';
import '../../modelos/torneo.dart';
import '../agentes_rivales.dart' as rivales;
import '../calendario.dart';
import '../formulas.dart';
import '../liga.dart';
import '../premios.dart';
import '../satisfaccion.dart' as sat;
import '../torneos.dart';
import '../motor_juego.dart';

/// Simulación y premios de las competiciones.
class CompeticionService {
  CompeticionService(this.motor);

  final MotorJuego motor;

  /// Construye una liga por cada combinación videojuego + región + división.
  List<Competicion> crearCompeticiones(List<Equipo> equipos) {
    final grupos = <String, List<Equipo>>{};
    for (final equipo in equipos) {
      final clave = '${equipo.juego.name}|${equipo.region}|${equipo.division}';
      grupos.putIfAbsent(clave, () => <Equipo>[]).add(equipo);
    }
    final lista = <Competicion>[];
    for (final grupo in grupos.values) {
      final primero = grupo.first;
      lista.add(
        Competicion(
          juego: primero.juego,
          region: primero.region,
          division: primero.division,
          liga: primero.liga,
          equipoIds: grupo.map((e) => e.id).toList(),
        ),
      );
    }
    return lista;
  }

  /// Calcula una sola vez los premios individuales de la temporada.
  void calcularPremiosTemporada() {
    final est = motor.estado!;
    // Si ya se entregaron los premios de esta temporada, no repito.
    if (est.premios.any((p) => p.temporada == est.temporada)) return;

    final puntosTitulos = _puntosTitulosPorJugador();
    final premiosTemporada = <PremioIndividual>[];
    for (final juego in Juego.values) {
      premiosTemporada.addAll(calcularPremios(est, juego, puntosTitulos));
    }
    final agenteDelAnio = calcularAgenteDelAnio(
      est,
      premiosExtra: premiosTemporada,
    );
    if (agenteDelAnio != null) premiosTemporada.add(agenteDelAnio);

    est.premios.addAll(premiosTemporada);
    aplicarEfectosPremios(est, premiosTemporada);
    est.ceremoniaPendiente = premiosTemporada.isNotEmpty;
  }

  /// Reconstruye los torneos de la temporada actual que falten (I14).
  ///
  /// Las partidas v3/v4 no guardaban `torneos`. Si al cargar ya se jugó la
  /// semana del Torneo de Mitad (21–22) o del Mundial (43–46), se crea el
  /// torneo y se simulan las semanas que correspondan. No se toca una
  /// partida que ya tenga sus torneos.
  void repararTorneosDeTemporada() {
    final est = motor.estado!;
    if (est.competiciones.isEmpty) return;

    if (est.semana >= 21) {
      for (final juego in Juego.values) {
        if (motor.torneoDe(juego, TipoTorneo.mitad) != null) continue;
        final torneo = crearTorneoMitad(est, juego, motor.indices.equipos);
        est.torneos.add(torneo);
        _simularTorneoHasta(torneo, 21, min(est.semana, 22));
      }
    }

    if (est.semana >= 43) {
      for (final juego in Juego.values) {
        if (motor.torneoDe(juego, TipoTorneo.mundial) != null) continue;
        final torneo = crearTorneoMundial(est, juego, motor.indices.equipos);
        est.torneos.add(torneo);
        _simularTorneoHasta(torneo, 43, min(est.semana, 46));
      }
    }
  }

  /// Simula un torneo recién reconstruido desde [desde] hasta [hasta].
  void _simularTorneoHasta(Torneo torneo, int desde, int hasta) {
    for (var semana = desde; semana <= hasta; semana++) {
      final campeonAntes = torneo.campeonId;
      if (torneo.tipo == TipoTorneo.mitad) {
        avanzarTorneoMitad(
          torneo,
          equipos: motor.indices.equipos,
          jugadores: motor.estado!.jugadores,
          rnd: motor.rnd,
          semana: semana,
        );
      } else {
        avanzarTorneoMundial(
          torneo,
          equipos: motor.indices.equipos,
          jugadores: motor.estado!.jugadores,
          rnd: motor.rnd,
          semana: semana,
        );
      }
      if (campeonAntes == null && torneo.campeonId != null) {
        _cerrarTorneo(torneo);
      }
    }
  }

  /// Puntos de títulos por jugador para el puntaje del Jugador del Año.
  Map<String, double> _puntosTitulosPorJugador() {
    final est = motor.estado!;
    final puntos = <String, double>{};
    final titulos = est.palmares
        .where((r) => r.temporada == est.temporada)
        .toList();
    for (final titulo in titulos) {
      double valor;
      if (titulo.tipo == TipoCampeon.torneo) {
        valor =
            (titulo.descripcion == 'Mundial' || titulo.descripcion == 'Major')
            ? puntosTituloMundial
            : puntosTituloMitad;
      } else {
        valor = puntosTituloLiga;
      }
      for (final j in est.jugadores) {
        if (j.equipoId == titulo.ganadorId) {
          puntos[j.id] = (puntos[j.id] ?? 0) + valor;
        }
      }
    }
    return puntos;
  }

  /// Simula lo que toca jugar en la semana actual en todas las ligas.
  void simularEtapaActual() {
    final est = motor.estado!;

    // Torneos internacionales (Parte 2C).
    if (est.semana >= 21 && est.semana <= 22) {
      _simularTorneosMitad();
    } else if (est.semana >= 43 && est.semana <= 46) {
      _simularMundial();
    }

    final split = splitDeLiga(est.semana);
    final fecha = fechaDeLiga(est.semana);
    final splitPlayoff = splitDePlayoffs(est.semana);

    for (final comp in est.competiciones) {
      if (split != null && fecha != null) {
        final antes = comp.resultadosDeSplit(split).length;
        simularFecha(
          comp,
          split,
          fecha,
          motor.indices.equipos,
          est.jugadores,
          motor.rnd,
        );
        final nuevos = comp.resultadosDeSplit(split).sublist(antes);
        _noticiasDeResultados(nuevos);
        _noticiasDeRachas(comp);
      } else if (splitPlayoff != null) {
        final antes = comp.resultadosPlayoffsDe(splitPlayoff).length;
        jugarPlayoffs(
          comp,
          splitPlayoff,
          motor.indices.equipos,
          est.jugadores,
          motor.rnd,
        );
        final playoffs = comp.resultadosPlayoffsDe(splitPlayoff);
        if (playoffs.length > antes &&
            comp.campeonSplit(splitPlayoff) != null) {
          _anunciarCampeon(comp, splitPlayoff);
        }
      }
    }
  }

  /// Crea y avanza el Torneo de Mitad de Temporada de cada videojuego.
  void _simularTorneosMitad() {
    final est = motor.estado!;
    for (final juego in Juego.values) {
      var torneo = motor.torneoDe(juego, TipoTorneo.mitad);
      if (torneo == null) {
        torneo = crearTorneoMitad(est, juego, motor.indices.equipos);
        est.torneos.add(torneo);
      }
      final campeonAntes = torneo.campeonId;
      avanzarTorneoMitad(
        torneo,
        equipos: motor.indices.equipos,
        jugadores: est.jugadores,
        rnd: motor.rnd,
        semana: est.semana,
      );
      if (campeonAntes == null && torneo.campeonId != null) {
        _cerrarTorneo(torneo);
      }
    }
  }

  /// Crea y avanza el Mundial (o Major) de cada videojuego.
  void _simularMundial() {
    final est = motor.estado!;
    for (final juego in Juego.values) {
      var torneo = motor.torneoDe(juego, TipoTorneo.mundial);
      if (torneo == null) {
        torneo = crearTorneoMundial(est, juego, motor.indices.equipos);
        est.torneos.add(torneo);
      }
      final campeonAntes = torneo.campeonId;
      avanzarTorneoMundial(
        torneo,
        equipos: motor.indices.equipos,
        jugadores: est.jugadores,
        rnd: motor.rnd,
        semana: est.semana,
      );
      if (campeonAntes == null && torneo.campeonId != null) {
        _cerrarTorneo(torneo);
      }
    }
  }

  /// Cierra un torneo: registra el título, reparte premios y aplica efectos.
  void _cerrarTorneo(Torneo torneo) {
    final est = motor.estado!;
    final campeonId = torneo.campeonId;
    if (campeonId == null) return;

    est.palmares.add(
      RegistroCampeon(
        temporada: torneo.temporada,
        juego: torneo.juego,
        descripcion: torneo.nombre,
        tipo: TipoCampeon.torneo,
        ganadorId: campeonId,
      ),
    );

    repartirPremios(torneo, motor.indices.equipos);

    final nombre = motor.indices.equipos[campeonId]?.nombre ?? campeonId;
    motor.agregarNoticia(
      '$nombre es campeón del ${torneo.nombre} de ${torneo.juego.corto}.',
      TipoNoticia.venta,
    );

    final premiados = aplicarEfectosCampeon(torneo, est.jugadores, est.agente);
    // Los rivales con clientes en el equipo campeón también ganan reputación.
    rivales.aplicarReputacionRivalesPorTitulo(
      est,
      campeonId,
      mundial: torneo.tipo == TipoTorneo.mundial,
    );
    if (premiados.isNotEmpty) {
      motor.agregarNoticia(
        '¡${premiados.map((j) => j.nick).join(', ')} '
        '${premiados.length > 1 ? 'ganaron' : 'ganó'} el ${torneo.nombre}! '
        'Suben su moral, su valor y tu reputación.',
        TipoNoticia.venta,
      );
    }
  }

  /// ¿Tengo algún representado en este equipo?
  bool _tengoRepresentadoEn(String equipoId) => motor.estado!.jugadores.any(
    (j) => j.representadoPorMi && j.equipoId == equipoId,
  );

  /// Noticias de los resultados donde juega algún representado mío.
  void _noticiasDeResultados(List<ResultadoSerie> resultados) {
    for (final r in resultados) {
      if (!_tengoRepresentadoEn(r.localId) &&
          !_tengoRepresentadoEn(r.visitanteId)) {
        continue;
      }
      final local = motor.indices.equipos[r.localId];
      final visitante = motor.indices.equipos[r.visitanteId];
      if (local == null || visitante == null) continue;
      motor.agregarNoticia(
        '${local.nombre} ${r.mapasLocal}–${r.mapasVisitante} ${visitante.nombre} '
        '(${r.etapa}).',
        TipoNoticia.evento,
      );
    }
  }

  /// Avisa cuando un equipo logra una racha de 4 victorias seguidas.
  void _noticiasDeRachas(Competicion comp) {
    for (final equipoId in comp.equipoIds) {
      if (comp.rachaGanadora(equipoId) == 4) {
        final equipo = motor.indices.equipos[equipoId];
        if (equipo != null) {
          motor.agregarNoticia(
            '${equipo.nombre} suma 4 victorias seguidas en ${comp.liga}.',
            TipoNoticia.progreso,
          );
        }
      }
    }
  }

  /// Anuncia y registra al campeón de un split.
  void _anunciarCampeon(Competicion comp, int split) {
    final campeonId = comp.campeonSplit(split);
    if (campeonId == null) return;
    final equipo = motor.indices.equipos[campeonId];
    final nombre = equipo?.nombre ?? campeonId;
    final texto = '$nombre es campeón de ${comp.liga} (Split $split).';
    final est = motor.estado!;
    if (!est.campeonesTemporada.contains(texto)) {
      est.campeonesTemporada.add(texto);
      motor.agregarNoticia(texto, TipoNoticia.venta);
      est.palmares.add(
        RegistroCampeon(
          temporada: est.temporada,
          juego: comp.juego,
          descripcion: '${comp.liga} (Split $split)',
          tipo: TipoCampeon.liga,
          ganadorId: campeonId,
        ),
      );
      // Un título de liga sube la satisfacción de mis representados del
      // equipo campeón (Parte 3B).
      for (final j in est.jugadores) {
        if (j.representadoPorMi && j.equipoId == campeonId) {
          sat.aplicarEfectoTitulo(j, mundial: false);
        }
      }
    }
  }
}
