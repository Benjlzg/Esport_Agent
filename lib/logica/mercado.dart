// Mercado de fichajes (Parte 2D): puntuación de candidatos, búsqueda rápida
// agrupando a los jugadores por videojuego y rol, y los fichajes automáticos
// de la IA. Los traspasos de la IA solo ocurren en ventana de fichajes.
import 'dart:math';

import '../modelos/equipo.dart';
import '../modelos/estado_partida.dart';
import '../modelos/jugador.dart';
import '../modelos/oferta.dart';
import 'formulas.dart';
import 'generador_jugadores.dart';

/// Puntaje de un jugador como candidato a fichaje (más alto = mejor).
/// `habilidad + (potencial − habilidad) × factorEdad + (forma − 3) × 3`.
double puntajeFichaje(Jugador j) {
  final forma = estrellasDeNotas(j.ultimasNotas);
  return j.habilidad +
      (j.potencial - j.habilidad) * factorEdadPuntaje(j.edad) +
      (forma - formaNeutra) * 3;
}

/// El titular (no suplente) más débil del equipo, o null si no tiene.
Jugador? titularMasDebil(Equipo equipo, List<Jugador> jugadores) {
  Jugador? debil;
  for (final j in jugadores) {
    if (j.equipoId != equipo.id || j.suplente) continue;
    if (debil == null || j.habilidad < debil.habilidad) debil = j;
  }
  return debil;
}

/// Agrupa a los jugadores por videojuego y rol. La clave es "juego|rol".
/// Se calcula una sola vez para que la búsqueda de candidatos sea rápida.
Map<String, List<Jugador>> agruparPorJuegoYRol(List<Jugador> jugadores) {
  final indice = <String, List<Jugador>>{};
  for (final j in jugadores) {
    indice.putIfAbsent('${j.juego.name}|${j.rol}', () => <Jugador>[]).add(j);
  }
  return indice;
}

/// Agrupa a los jugadores por equipo. También se calcula una sola vez.
Map<String, List<Jugador>> agruparPorEquipo(List<Jugador> jugadores) {
  final indice = <String, List<Jugador>>{};
  for (final j in jugadores) {
    final equipoId = j.equipoId;
    if (equipoId != null) {
      indice.putIfAbsent(equipoId, () => <Jugador>[]).add(j);
    }
  }
  return indice;
}

/// Candidatos para reforzar un rol de un equipo: mismo videojuego y rol, con
/// habilidad suficiente sobre el titular más débil y que el equipo pueda
/// pagar. Se ordenan priorizando agentes libres, equipos de menor prestigio
/// y jugadores de la misma región; dentro de cada grupo, por puntaje.
List<Jugador> candidatosPara({
  required Equipo equipo,
  required Map<String, List<Jugador>> porJuegoRol,
  required Map<String, Equipo> indiceEquipos,
  required String rol,
  required int umbralHabilidad,
  required int temporadaActual,
}) {
  final grupo = porJuegoRol['${equipo.juego.name}|$rol'] ?? const <Jugador>[];
  final lista = grupo.where((j) {
    if (j.equipoId == equipo.id) return false;
    // Recién fichado: la IA tampoco puede comprarlo esta temporada (A2).
    if (j.bloqueadoTraspaso(temporadaActual)) return false;
    if (j.habilidad < umbralHabilidad) return false;
    if (j.valorMercado > equipo.presupuesto) return false;
    return true;
  }).toList();

  int prioridad(Jugador j) {
    if (j.equipoId == null) return 0;
    final origen = indiceEquipos[j.equipoId!];
    if (origen != null && origen.prestigio < equipo.prestigio) return 1;
    return 2;
  }

  lista.sort((a, b) {
    final pa = prioridad(a);
    final pb = prioridad(b);
    if (pa != pb) return pa.compareTo(pb);
    final ra = (a.region != null && a.region == equipo.region) ? 0 : 1;
    final rb = (b.region != null && b.region == equipo.region) ? 0 : 1;
    if (ra != rb) return ra.compareTo(rb);
    return puntajeFichaje(b).compareTo(puntajeFichaje(a));
  });
  return lista;
}

/// Deja como máximo [maxSuplentesPorEquipo] suplentes en el equipo. Si sobran,
/// los más débiles quedan libres. Devuelve los jugadores liberados.
List<Jugador> recortarSuplentes(EstadoPartida estado, Equipo equipo) {
  final suplentes = estado.jugadores
      .where((j) => j.equipoId == equipo.id && j.suplente)
      .toList();
  if (suplentes.length <= maxSuplentesPorEquipo) return const [];

  suplentes.sort((a, b) => a.habilidad.compareTo(b.habilidad));
  final sobrantes = suplentes.length - maxSuplentesPorEquipo;
  final liberados = <Jugador>[];
  for (var i = 0; i < sobrantes; i++) {
    final j = suplentes[i];
    j.equipoId = null;
    j.suplente = false;
    j.semanasContrato = 0;
    j.semanasComoSuplente = 0;
    liberados.add(j);
  }
  return liberados;
}

/// Si un equipo perdió a su titular en un rol, genera un reemplazo ficticio
/// acorde a su prestigio. Devuelve el jugador nuevo (ya añadido al estado) o
/// null si el rol ya tiene titular.
Jugador? generarReemplazoSiFalta({
  required EstadoPartida estado,
  required Map<String, Equipo> indiceEquipos,
  required Random rnd,
  required String Function() nuevoIdJugador,
  required String equipoId,
  required String rol,
}) {
  final tieneTitular = estado.jugadores.any(
    (j) => j.equipoId == equipoId && j.rol == rol && !j.suplente,
  );
  if (tieneTitular) return null;
  final equipo = indiceEquipos[equipoId];
  if (equipo == null) return null;

  final nicksUsados = estado.jugadores.map((j) => j.nick).toSet();
  final reemplazo = generarJugadorParaEquipo(
    rnd,
    id: nuevoIdJugador(),
    equipo: equipo,
    rol: rol,
    ajusteHabilidad: ajusteHabilidadReemplazo,
    nicksUsados: nicksUsados,
  );
  estado.jugadores.add(reemplazo);
  return reemplazo;
}

/// Resultado de procesar el mercado: noticias y ofertas nuevas.
class ResultadoMercadoIA {
  ResultadoMercadoIA({
    required this.noticias,
    required this.ofertas,
    this.fichajesCerrados = 0,
  });

  /// Textos de noticias para que el motor los registre.
  final List<String> noticias;

  /// Ofertas de traspaso por jugadores míos (pendientes de respuesta).
  final List<Oferta> ofertas;

  /// Traspasos automáticos que la IA cerró en esta llamada.
  final int fichajesCerrados;
}

/// Procesa el mercado de la IA en la semana actual. Cada equipo intenta un
/// fichaje con cierta probabilidad, respetando el máximo por ventana.
///
/// Antes de empezar agrupa a todos los jugadores por videojuego y rol (y por
/// equipo) para que la búsqueda de candidatos sea rápida y "Avanzar semana"
/// no se ponga lento.
ResultadoMercadoIA procesarMercadoIA({
  required EstadoPartida estado,
  required Map<String, Equipo> indiceEquipos,
  required Map<String, Jugador> indiceJugadores,
  required Random rnd,
  required String Function() nuevoIdJugador,
}) {
  final noticias = <String>[];
  final ofertas = <Oferta>[];
  var fichajesCerrados = 0;

  // Índices que se calculan una sola vez para toda la semana.
  final porJuegoRol = agruparPorJuegoYRol(estado.jugadores);
  final porEquipo = agruparPorEquipo(estado.jugadores);

  for (final equipo in estado.equipos) {
    final usados = estado.fichajesVentana[equipo.id] ?? 0;
    if (usados >= maxFichajesPorVentana) continue;

    // Solo intenta fichar en algunas semanas de la ventana.
    if (rnd.nextDouble() >= probIntentarFichaje) continue;

    final roster = porEquipo[equipo.id] ?? const <Jugador>[];
    final debil = titularMasDebil(equipo, roster);
    if (debil == null) continue;

    final umbral = debil.habilidad + diferenciaMinimaFichaje;
    final candidatos = candidatosPara(
      equipo: equipo,
      porJuegoRol: porJuegoRol,
      indiceEquipos: indiceEquipos,
      rol: debil.rol,
      umbralHabilidad: umbral,
      temporadaActual: estado.temporada,
    );
    if (candidatos.isEmpty) continue;

    final elegido = candidatos.first;

    // Si el candidato es mío, el equipo me hace una oferta (no se cierra sola).
    if (elegido.representadoPorMi) {
      // No repetir una oferta ya pendiente del mismo equipo por ese jugador.
      final yaPendiente = estado.ofertas.any(
        (o) =>
            o.tipo == TipoOferta.traspaso &&
            o.jugadorId == elegido.id &&
            o.equipoId == equipo.id,
      );
      if (yaPendiente) continue;
      final oferta = Oferta(
        id: 'of_${elegido.id}_${equipo.id}_${estado.temporada}_${estado.semana}',
        tipo: TipoOferta.traspaso,
        jugadorId: elegido.id,
        equipoId: equipo.id,
        monto: elegido.valorMercado,
        salarioAnual: calcularSalarioAnual(elegido.valorMercado),
        semanasRestantes: 2,
        temporada: estado.temporada,
        semana: estado.semana,
      );
      ofertas.add(oferta);
      estado.ofertas.add(oferta);
      estado.fichajesVentana[equipo.id] = usados + 1;
      continue;
    }

    // Traspaso automático de la IA, con probabilidad de éxito.
    if (rnd.nextDouble() > probExitoTraspasoIA) continue;

    final origenId = elegido.equipoId;

    // El jugador desplazado en ese rol baja a suplente; si sobran suplentes,
    // el más débil queda libre.
    debil.suplente = true;
    final liberados = recortarSuplentes(estado, equipo);
    for (final j in liberados) {
      noticias.add(
        '${j.nick} quedó libre para hacer sitio en ${equipo.nombre}.',
      );
    }

    // Se cierra el traspaso.
    equipo.presupuesto = max(0, equipo.presupuesto - elegido.valorMercado);
    elegido.equipoId = equipo.id;
    elegido.suplente = false;
    elegido.semanasContrato = 52 + rnd.nextInt(53);
    elegido.semanasComoSuplente = 0;
    // Queda bloqueado para otro traspaso hasta la próxima temporada (A2).
    elegido.temporadaUltimoTraspaso = estado.temporada;
    estado.fichajesVentana[equipo.id] = usados + 1;
    fichajesCerrados++;

    // Reponer el hueco dejado en el equipo de origen.
    if (origenId != null && origenId != equipo.id) {
      final reemplazo = generarReemplazoSiFalta(
        estado: estado,
        indiceEquipos: indiceEquipos,
        rnd: rnd,
        nuevoIdJugador: nuevoIdJugador,
        equipoId: origenId,
        rol: elegido.rol,
      );
      if (reemplazo != null) {
        indiceJugadores[reemplazo.id] = reemplazo;
        porJuegoRol
            .putIfAbsent(
              '${reemplazo.juego.name}|${reemplazo.rol}',
              () => <Jugador>[],
            )
            .add(reemplazo);
      }
    }

    // Noticias de fichajes importantes.
    if (elegido.habilidad >= 80 || equipo.prestigio >= 85) {
      noticias.add(
        '${equipo.nombre} ficha a ${elegido.nick} '
        '(${elegido.rol}, ${elegido.habilidad} de habilidad).',
      );
    }
  }

  return ResultadoMercadoIA(
    noticias: noticias,
    ofertas: ofertas,
    fichajesCerrados: fichajesCerrados,
  );
}
