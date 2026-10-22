// Mercado de fichajes (Parte 2D): puntuación de candidatos, búsqueda rápida
// agrupando a los jugadores por videojuego y rol, y los fichajes automáticos
// de la IA. Los traspasos de la IA solo ocurren en ventana de fichajes.
import 'dart:math';

import '../modelos/equipo.dart';
import '../modelos/estado_partida.dart';
import '../modelos/historial.dart';
import '../modelos/jugador.dart';
import '../modelos/oferta.dart';
import 'formulas.dart';
import 'generador_jugadores.dart';

/// Títulos de split de 1ª División en las últimas [temporadasVentanaDinastia]
/// que convierten a un equipo en dinastía.
const int titulosParaSerDinastia = 3;
const int temporadasVentanaDinastia = 5;

/// Puntaje de un jugador como candidato a fichaje (más alto = mejor).
/// `habilidad + (potencial − habilidad) × factorEdad + (forma − 3) × 3`.
double puntajeFichaje(Jugador j) {
  final forma = estrellasDeNotas(j.ultimasNotas);
  return j.habilidad +
      (j.potencial - j.habilidad) * factorEdadPuntaje(j.edad) +
      (forma - formaNeutra) * 3;
}

/// El titular (no suplente) más débil del equipo, o null si no tiene.
///
/// [titularesPorRol] es el índice del equipo (rol → titular). Si se pasa, no
/// hace falta recorrer la lista de todos los jugadores (corrección I9).
Jugador? titularMasDebil(
  Equipo equipo,
  List<Jugador> jugadores, {
  Map<String, Jugador>? titularesPorRol,
}) {
  if (titularesPorRol != null) {
    Jugador? debil;
    for (final j in titularesPorRol.values) {
      if (debil == null || j.habilidad < debil.habilidad) debil = j;
    }
    return debil;
  }
  Jugador? debil;
  for (final j in jugadores) {
    if (j.equipoId != equipo.id || j.suplente) continue;
    if (debil == null || j.habilidad < debil.habilidad) debil = j;
  }
  return debil;
}

/// Construye el índice equipo → (rol → titular) en una sola pasada.
///
/// Es la estructura que evita el bucle O(equipos × roles × jugadores) de la
/// red de seguridad del mercado (corrección I9).
Map<String, Map<String, Jugador>> titularesPorEquipoRol(
  Map<String, List<Jugador>> porEquipo,
) {
  final indice = <String, Map<String, Jugador>>{};
  for (final entrada in porEquipo.entries) {
    indice[entrada.key] = _titularesDeLista(entrada.value);
  }
  return indice;
}

Map<String, Jugador> _titularesDeLista(List<Jugador> plantilla) {
  final porRol = <String, Jugador>{};
  for (final jugador in plantilla) {
    if (jugador.suplente) continue;
    final actual = porRol[jugador.rol];
    if (actual == null || jugador.habilidad > actual.habilidad) {
      porRol[jugador.rol] = jugador;
    }
  }
  return porRol;
}

/// Recalcula el índice de titulares de un equipo tras un movimiento.
void _actualizarTitularesDeEquipo(
  Map<String, Map<String, Jugador>> titulares,
  Map<String, List<Jugador>> porEquipo,
  String equipoId,
) {
  titulares[equipoId] = _titularesDeLista(
    porEquipo[equipoId] ?? const <Jugador>[],
  );
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

/// Al empezar la temporada, algunos equipos de 2ª División fichan a un joven
/// libre de su región como suplente (C3).
///
/// Reglas de seguridad:
/// - Nunca ficha a un jugador representado por el agente: si es mío, la
///   decisión debe llegar como oferta (o quedarse libre), no automática.
/// - Solo acepta jóvenes de 21 años o menos.
/// - Respeta el máximo de suplentes del equipo.
/// - Marca el fichaje como reciente para que no se revenda en la temporada.
///
/// El parámetro [probabilidad] existe para poder forzar el fichaje en las
/// pruebas; en el juego se usa [probSegundaDivisionFichaJoven].
void ficharJovenesDeSegunda({
  required EstadoPartida estado,
  required Random rnd,
  double probabilidad = probSegundaDivisionFichaJoven,
}) {
  for (final equipo in estado.equipos) {
    if (equipo.division != 2) continue;
    if (rnd.nextDouble() >= probabilidad) continue;

    // No se puede superar el máximo de suplentes del equipo.
    final suplentesActuales = estado.jugadores
        .where((j) => j.equipoId == equipo.id && j.suplente)
        .length;
    if (suplentesActuales >= maxSuplentesPorEquipo) continue;

    Jugador? joven;
    for (final j in estado.jugadores) {
      if (j.equipoId != null) continue;
      if (j.representadoPorMi) continue;
      if (j.edad > 21) continue;
      if (j.juego != equipo.juego) continue;
      if (j.region != equipo.region) continue;
      if (j.bloqueadoTraspaso(estado.temporada)) continue;
      joven = j;
      break;
    }
    if (joven == null) continue;

    joven.equipoId = equipo.id;
    joven.suplente = true;
    joven.semanasContrato = 52 + rnd.nextInt(53);
    joven.semanasComoSuplente = 0;
    // Recién fichado: no puede volver a cambiar de equipo esta temporada.
    joven.temporadaUltimoTraspaso = estado.temporada;
  }
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

  // Al abrir la primera ventana de la temporada, los rivales intentan
  // llevarse a una figura de los campeones de la temporada anterior. Va antes
  // del mercado normal para que los compradores todavía tengan presupuesto.
  if (estado.semana == 1) {
    fichajesCerrados += _fichajesDeCampeones(
      estado: estado,
      indiceEquipos: indiceEquipos,
      indiceJugadores: indiceJugadores,
      porEquipo: porEquipo,
      porJuegoRol: porJuegoRol,
      rnd: rnd,
      nuevoIdJugador: nuevoIdJugador,
      noticias: noticias,
      ofertas: ofertas,
    );
  }

  // Orden aleatorio: antes los equipos más fuertes (que van primero en la
  // lista) elegían siempre los mejores agentes libres y aumentaban su ventaja.
  //
  // El índice de titulares se construye una sola vez después del anti-dinastía
  // y se actualiza con cada traspaso (corrección I9).
  final titulares = titularesPorEquipoRol(porEquipo);
  final dinastias = equiposDinastia(estado);
  final equiposEnOrden = List<Equipo>.from(estado.equipos)..shuffle(rnd);
  for (final equipo in equiposEnOrden) {
    final usados = estado.fichajesVentana[equipo.id] ?? 0;
    if (usados >= maxFichajesPorVentana) continue;

    // Solo intenta fichar en algunas semanas de la ventana.
    if (rnd.nextDouble() >= probIntentarFichaje) continue;

    final roster = porEquipo[equipo.id] ?? const <Jugador>[];
    final debil = titularMasDebil(
      equipo,
      roster,
      titularesPorRol: titulares[equipo.id],
    );
    if (debil == null) continue;

    final umbral = debil.habilidad + diferenciaMinimaFichaje;
    var candidatos = candidatosPara(
      equipo: equipo,
      porJuegoRol: porJuegoRol,
      indiceEquipos: indiceEquipos,
      rol: debil.rol,
      umbralHabilidad: umbral,
      temporadaActual: estado.temporada,
    );

    // Una dinastía que vendió figuras por la cláusula anti-dinastía no puede
    // usar ese dinero para fichar a alguien mejor que su mejor titular actual.
    // Antes volvía a comprar el mejor agente libre y la liga seguía dominada.
    if (dinastias.contains(equipo.id)) {
      final titularesEquipo = titulares[equipo.id];
      if (titularesEquipo == null || titularesEquipo.isEmpty) continue;
      final mejorHabilidad = titularesEquipo.values
          .map((j) => j.habilidad)
          .reduce(max);
      candidatos = candidatos
          .where((j) => j.habilidad <= mejorHabilidad)
          .toList();
    }
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
        equipoOrigenId: elegido.equipoId,
        monto: elegido.valorMercado,
        salarioAnual: calcularSalarioAnual(elegido.valorMercado),
        semanasRestantes: 2,
        mejorasRealizadas: 0,
        montoMaximo: topeMontoOferta(
          valorMercado: elegido.valorMercado,
          presupuesto: equipo.presupuesto,
        ),
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
      porEquipo[equipo.id]?.removeWhere((x) => x.id == j.id);
      noticias.add(
        '${j.nick} quedó libre para hacer sitio en ${equipo.nombre}.',
      );
    }
    _actualizarTitularesDeEquipo(titulares, porEquipo, equipo.id);

    // Se cierra el traspaso. El candidato ya se filtró por presupuesto.
    equipo.presupuesto -= elegido.valorMercado;
    // El club vendedor recibe el precio. En un traspaso entre equipos de la
    // IA no hay agente mío, así que no se descuenta comisión (I2).
    final clubVendedor = origenId == null ? null : indiceEquipos[origenId];
    if (clubVendedor != null && clubVendedor.id != equipo.id) {
      clubVendedor.presupuesto += elegido.valorMercado;
    }
    // El jugador cambia de lista de equipo también en el índice local.
    if (origenId != null) {
      porEquipo[origenId]?.removeWhere((j) => j.id == elegido.id);
    }
    porEquipo.putIfAbsent(equipo.id, () => <Jugador>[]).add(elegido);
    elegido.equipoId = equipo.id;
    elegido.suplente = false;
    elegido.semanasContrato = 52 + rnd.nextInt(53);
    elegido.semanasComoSuplente = 0;
    // El salario del nuevo contrato se aplica también en la IA (I7).
    elegido.salarioAnual = calcularSalarioAnual(elegido.valorMercado);
    // Queda bloqueado para otro traspaso hasta la próxima temporada (A2).
    elegido.temporadaUltimoTraspaso = estado.temporada;
    estado.fichajesVentana[equipo.id] = usados + 1;
    fichajesCerrados++;
    _actualizarTitularesDeEquipo(titulares, porEquipo, equipo.id);
    if (origenId != null) {
      _actualizarTitularesDeEquipo(titulares, porEquipo, origenId);
    }

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
        porEquipo.putIfAbsent(origenId, () => <Jugador>[]).add(reemplazo);
        porJuegoRol
            .putIfAbsent(
              '${reemplazo.juego.name}|${reemplazo.rol}',
              () => <Jugador>[],
            )
            .add(reemplazo);
        _actualizarTitularesDeEquipo(titulares, porEquipo, origenId);
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

  // Red de seguridad: si una sucesión de fichajes dejó a un equipo sin
  // titular en algún rol, se repone antes de cerrar la semana. Sin esto,
  // el recorte de suplentes podía dejar plantillas de 4 titulares.
  _garantizarTitulares(
    estado: estado,
    indiceEquipos: indiceEquipos,
    rnd: rnd,
    nuevoIdJugador: nuevoIdJugador,
    indiceJugadores: indiceJugadores,
    titulares: titulares,
    porEquipo: porEquipo,
  );

  return ResultadoMercadoIA(
    noticias: noticias,
    ofertas: ofertas,
    fichajesCerrados: fichajesCerrados,
  );
}

/// Comprueba que cada equipo tenga un titular en todos los roles de su juego.
/// Si falta alguno, genera un reemplazo. Es una red de seguridad para que una
/// cadena de traspasos y recortes no deje plantillas incompletas.
void _garantizarTitulares({
  required EstadoPartida estado,
  required Map<String, Equipo> indiceEquipos,
  required Random rnd,
  required String Function() nuevoIdJugador,
  required Map<String, Jugador> indiceJugadores,
  required Map<String, Map<String, Jugador>> titulares,
  required Map<String, List<Jugador>> porEquipo,
}) {
  for (final equipo in estado.equipos) {
    final porRol = titulares[equipo.id] ?? const <String, Jugador>{};
    for (final rol in equipo.juego.roles) {
      // Antes se recorría toda la lista de jugadores para cada equipo y rol.
      // Ahora el índice dice directamente si el rol tiene titular (I9).
      if (porRol[rol] != null) continue;
      final reemplazo = generarReemplazoSiFalta(
        estado: estado,
        indiceEquipos: indiceEquipos,
        rnd: rnd,
        nuevoIdJugador: nuevoIdJugador,
        equipoId: equipo.id,
        rol: rol,
      );
      if (reemplazo != null) {
        indiceJugadores[reemplazo.id] = reemplazo;
        porEquipo.putIfAbsent(equipo.id, () => <Jugador>[]).add(reemplazo);
        _actualizarTitularesDeEquipo(titulares, porEquipo, equipo.id);
      }
    }
  }
}

/// ¿El título de liga pertenece a la 1ª División?
///
/// Si la partida no trae competiciones (datos de prueba o guardados muy
/// antiguos), se acepta el título para no romper el comportamiento anterior.
bool tituloEsDePrimeraDivision(EstadoPartida estado, RegistroCampeon titulo) {
  if (estado.competiciones.isEmpty) return true;
  for (final comp in estado.competiciones) {
    if (comp.division != 1) continue;
    if (titulo.descripcion.startsWith('${comp.liga} (Split')) return true;
  }
  return false;
}

/// Títulos de liga de 1ª División por equipo en la ventana móvil de dinastía.
///
/// Se usa tanto para el anti-dinastía como para limitar los fichajes de un
/// equipo que ya domina: así el dinero de una venta no le permite volver a
/// comprar figuras por encima de su propio nivel.
Map<String, int> titulosRecientesDePrimeraDivision(EstadoPartida estado) {
  final desde = estado.temporada - temporadasVentanaDinastia;
  final titulos = <String, int>{};
  for (final r in estado.palmares) {
    if (r.tipo != TipoCampeon.liga) continue;
    if (r.temporada < desde || r.temporada >= estado.temporada) continue;
    if (!tituloEsDePrimeraDivision(estado, r)) continue;
    titulos[r.ganadorId] = (titulos[r.ganadorId] ?? 0) + 1;
  }
  return titulos;
}

/// Equipos que son dinastía: 3+ títulos de split de 1ª División en 5 temporadas.
Set<String> equiposDinastia(EstadoPartida estado) {
  final titulos = titulosRecientesDePrimeraDivision(estado);
  return {
    for (final entrada in titulos.entries)
      if (entrada.value >= titulosParaSerDinastia) entrada.key,
  };
}

/// Intenta debilitar a las dinastías: equipos con 3 o más títulos de split
/// en las últimas 5 temporadas pierden figuras a manos de equipos que no
/// están en esa lista. Devuelve cuántos traspasos se cerraron.
///
/// Solo se ejecuta una vez por temporada (semana 1). Si la figura elegida es
/// un jugador representado por el agente, no se cambia de club: se genera una
/// [Oferta] con el importe de la cláusula para que tú decidas (C3/C4).
int _fichajesDeCampeones({
  required EstadoPartida estado,
  required Map<String, Equipo> indiceEquipos,
  required Map<String, Jugador> indiceJugadores,
  required Map<String, List<Jugador>> porEquipo,
  required Map<String, List<Jugador>> porJuegoRol,
  required Random rnd,
  required String Function() nuevoIdJugador,
  required List<String> noticias,
  required List<Oferta> ofertas,
}) {
  if (estado.temporada < 2) return 0;

  // Cuento los títulos de liga de las últimas 5 temporadas. Una dinastía
  // sigue perdiendo figuras aunque falle un año.
  final titulosRecientes = titulosRecientesDePrimeraDivision(estado);
  // Se debilita a los campeones de la temporada anterior y, sobre todo, a
  // las dinastías con 3 o más títulos de split en las últimas 5 temporadas.
  final campeones = <String>{
    ...estado.palmares
        .where(
          (r) =>
              r.temporada == estado.temporada - 1 &&
              r.tipo == TipoCampeon.liga &&
              tituloEsDePrimeraDivision(estado, r),
        )
        .map((r) => r.ganadorId),
    ...titulosRecientes.entries
        .where((e) => e.value >= titulosParaSerDinastia)
        .map((e) => e.key),
  };
  // Solo los equipos de 1ª División pueden ser dinastías de la élite.
  campeones.removeWhere((id) => (indiceEquipos[id]?.division ?? 1) != 1);
  if (campeones.isEmpty) return 0;

  var cerrados = 0;
  for (final campeonId in campeones) {
    final campeon = indiceEquipos[campeonId];
    if (campeon == null) continue;

    // Cuanto más dominante es un equipo, más rivales intentan quitarle
    // jugadores. La cláusula de salida (40 % del valor) permite que equipos
    // con menos presupuesto puedan reforzarse; sin ella, los traspasos contra
    // campeones casi nunca se cerraban porque sus figuras valían más que el
    // presupuesto rival.
    final titulos = titulosRecientes[campeonId] ?? 0;
    final maxRobos = 3 + (titulos >= 5 ? 1 : 0) + (titulos >= 7 ? 1 : 0);
    // Una dinastía con 6+ títulos recientes pierde seguro a todos sus
    // titulares que los rivales puedan pagar: es el freno más fuerte contra
    // un campeón que se perpetúa.
    final probabilidad = titulos >= 6 ? 1.0 : probFichajeDeCampeon;
    final rolesVendidos = <String>{};
    var robados = 0;
    while (robados < maxRobos && rnd.nextDouble() < probabilidad) {
      final plantilla =
          (porEquipo[campeonId] ?? const <Jugador>[])
              .where(
                (j) =>
                    !j.estaInactivo &&
                    !rolesVendidos.contains(j.rol) &&
                    // Un jugador recién traspasado no puede volver a
                    // cambiar de equipo en la misma temporada (M14).
                    !j.bloqueadoTraspaso(estado.temporada),
              )
              .toList()
            ..sort((a, b) => b.habilidad.compareTo(a.habilidad));

      var cerrado = false;
      for (final jugador in plantilla) {
        final precioClausula = max(
          1000,
          ((jugador.valorMercado * 0.40) / 1000).round() * 1000,
        );

        // Busco un comprador del mismo juego, con nivel y dinero suficientes.
        // El margen de 20 puntos permite que el segundo o tercer equipo de la
        // liga se refuerce con una figura del campeón.
        final compradores = estado.equipos.where((e) {
          if (e.id == campeon.id || e.juego != campeon.juego) return false;
          // La dinastía se mide en 1ª División, así que el comprador debe
          // competir en la misma división (M14).
          if (e.division != campeon.division) return false;
          // El comprador no puede ser otra dinastía: si no, las figuras
          // circulan entre los mismos equipos fuertes y la liga no se abre.
          if (campeones.contains(e.id)) return false;
          if (e.prestigio < campeon.prestigio - 20) return false;
          if (e.presupuesto < precioClausula) return false;
          return (estado.fichajesVentana[e.id] ?? 0) < maxFichajesPorVentana;
        }).toList()..sort((a, b) => b.prestigio.compareTo(a.prestigio));
        if (compradores.isEmpty) continue;

        // El comprador más fuerte es el que más interés tiene en debilitar al
        // campeón; si hay varios, se elige uno al azar entre los tres primeros.
        final limite = compradores.length < 3 ? compradores.length : 3;
        final comprador = compradores[rnd.nextInt(limite)];

        // Si la figura es mía, la dinastía no la ficha sola: me llega una
        // oferta por el importe de la cláusula y decido si acepto o no.
        if (jugador.representadoPorMi) {
          final yaPendiente = estado.ofertas.any(
            (o) =>
                o.tipo == TipoOferta.traspaso &&
                o.jugadorId == jugador.id &&
                o.equipoId == comprador.id,
          );
          if (!yaPendiente) {
            final oferta = Oferta(
              id:
                  'of_dinastia_${jugador.id}_${comprador.id}_'
                  '${estado.temporada}_${estado.semana}',
              tipo: TipoOferta.traspaso,
              jugadorId: jugador.id,
              equipoId: comprador.id,
              equipoOrigenId: campeon.id,
              monto: precioClausula,
              salarioAnual: calcularSalarioAnual(jugador.valorMercado),
              semanasRestantes: 2,
              mejorasRealizadas: 0,
              montoMaximo: topeMontoOferta(
                valorMercado: jugador.valorMercado,
                presupuesto: comprador.presupuesto,
              ),
              temporada: estado.temporada,
              semana: estado.semana,
            );
            ofertas.add(oferta);
            estado.ofertas.add(oferta);
            noticias.add(
              '${comprador.nombre} ofrece pagar la cláusula de salida de '
              '${jugador.nick}, figura de ${campeon.nombre}, por '
              '${formatearDinero(precioClausula)}. La decisión es tuya.',
            );
          }
          // El rol ya está ocupado por esta tentativa; no se insiste con otro
          // jugador del mismo rol en la misma dinastía.
          rolesVendidos.add(jugador.rol);
          robados++;
          cerrado = true;
          break;
        }

        // El jugador desplazado en ese rol pasa a suplente.
        for (final otro in estado.jugadores) {
          if (otro.id != jugador.id &&
              otro.equipoId == comprador.id &&
              otro.rol == jugador.rol &&
              !otro.suplente) {
            otro.suplente = true;
          }
        }
        for (final sobrante in recortarSuplentes(estado, comprador)) {
          noticias.add(
            '${sobrante.nick} quedó libre para hacer sitio en ${comprador.nombre}.',
          );
        }

        comprador.presupuesto -= precioClausula;
        // La dinastía vendedora recibe el importe de la cláusula. Si el
        // jugador no es mío no hay comisión de agente que descontar (I2).
        campeon.presupuesto += precioClausula;
        jugador.equipoId = comprador.id;
        jugador.suplente = false;
        jugador.semanasContrato = 52 + rnd.nextInt(53);
        jugador.semanasComoSuplente = 0;
        // También en las cláusulas se aplica el salario del nuevo contrato.
        jugador.salarioAnual = calcularSalarioAnual(jugador.valorMercado);
        jugador.temporadaUltimoTraspaso = estado.temporada;
        estado.fichajesVentana[comprador.id] =
            (estado.fichajesVentana[comprador.id] ?? 0) + 1;

        // Actualizo los índices locales que usa el resto del mercado.
        porEquipo[campeon.id]?.remove(jugador);
        porEquipo.putIfAbsent(comprador.id, () => <Jugador>[]).add(jugador);

        noticias.add(
          '${comprador.nombre} paga la cláusula de salida de ${jugador.nick}, '
          'figura de ${campeon.nombre}, que pierde una pieza tras su título.',
        );

        // El campeón repone el rol si se quedó sin titular.
        final reemplazo = generarReemplazoSiFalta(
          estado: estado,
          indiceEquipos: indiceEquipos,
          rnd: rnd,
          nuevoIdJugador: nuevoIdJugador,
          equipoId: campeon.id,
          rol: jugador.rol,
        );
        if (reemplazo != null) {
          porEquipo.putIfAbsent(campeon.id, () => <Jugador>[]).add(reemplazo);
          // El reemplazo también debe entrar en los índices que usa el resto
          // del mercado y el motor (corrección I8).
          indiceJugadores[reemplazo.id] = reemplazo;
          porJuegoRol
              .putIfAbsent(
                '${reemplazo.juego.name}|${reemplazo.rol}',
                () => <Jugador>[],
              )
              .add(reemplazo);
        }

        rolesVendidos.add(jugador.rol);
        robados++;
        cerrados++;
        cerrado = true;
        break;
      }
      if (!cerrado) break;
    }
  }
  return cerrados;
}
