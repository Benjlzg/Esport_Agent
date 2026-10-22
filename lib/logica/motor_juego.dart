// Motor del juego: guarda todo el estado y contiene las acciones
// (reclutar, ofrecer, avanzar semana...). Extiende ChangeNotifier para
// que las pantallas se actualicen solas cuando algo cambia.
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../datos/cargador_mundo.dart';
import '../modelos/agente.dart';
import '../modelos/competicion.dart';
import '../modelos/equipo.dart';
import '../modelos/estado_partida.dart';
import '../modelos/evento.dart';
import '../modelos/historial.dart';
import '../modelos/juego.dart';
import '../modelos/jugador.dart';
import '../modelos/noticia.dart';
import '../modelos/oferta.dart';
import '../modelos/partido.dart';
import '../modelos/torneo.dart';
import '../servicios/guardado.dart';
import 'ascensos.dart';
import 'calendario.dart';
import 'eventos.dart' as eventos;
import 'formulas.dart';
import 'generador_jugadores.dart';
import 'liga.dart';
import 'mantenimiento.dart';
import 'mercado.dart';
import 'metricas.dart';
import 'negociacion.dart';
import 'premios.dart';
import 'progresion.dart';
import 'renovaciones.dart';
import 'torneos.dart';

/// Resultado simple de una acción (reclutar, dejar de representar...).
class ResultadoAccion {
  ResultadoAccion(this.ok, this.mensaje);

  final bool ok;
  final String mensaje;
}

/// Un partido que se jugará próximamente en el que participa un equipo
/// con jugadores representados por mí.
class PartidoProgramado {
  PartidoProgramado({
    required this.competicion,
    required this.fecha,
    required this.miEquipoId,
    required this.rivalId,
    required this.misJugadores,
  });

  final Competicion competicion;
  final int fecha;
  final String miEquipoId;
  final String rivalId;
  final List<Jugador> misJugadores;
}

/// Nivel de interés de un equipo por un jugador.
enum NivelInteres { muyInteresado, interesado, sinInteres }

/// Cuántas rondas de negociación se permiten por jugador y equipo.
const int maxRondasNegociacion = 3;

/// El motor principal del juego.
class MotorJuego extends ChangeNotifier {
  /// Crea el motor. Si se indica [semilla], todas las tiradas aleatorias de
  /// la partida son reproducibles. Con `null` se comporta como siempre.
  MotorJuego({int? semilla}) : semilla = semilla, _rnd = Random(semilla);

  /// Estado de la partida. Es null mientras no se ha creado o cargado.
  EstadoPartida? estado;

  /// Semilla usada por este motor (null = aleatoria del sistema).
  final int? semilla;

  final Random _rnd;

  /// Contadores en memoria para las pruebas de balance y el robot.
  /// No se guardan en la partida.
  final MetricasSimulacion metricas = MetricasSimulacion();

  /// true mientras se está ejecutando un avance de semana. Evita que un doble
  /// toque en "Avanzar semana" avance dos semanas (corrección I5).
  bool _avanzando = false;

  /// ¿Hay un avance de semana en curso?
  bool get avanzando => _avanzando;

  /// Cola de guardado: serializa las escrituras para que dos guardados
  /// simultáneos no terminen fuera de orden en el disco (corrección I5).
  final List<({EstadoPartida estado, Completer<void> completer})>
  _guardadosPendientes = [];
  bool _procesandoGuardado = false;

  /// Índices para buscar jugadores y equipos por id en O(1).
  final Map<String, Jugador> _indiceJugadores = {};
  final Map<String, Equipo> _indiceEquipos = {};

  /// Contador para crear identificadores únicos.
  ///
  /// El valor real vive en `EstadoPartida.siguienteIdJugador` para que se
  /// guarde con la partida. Antes era solo memoria y, al cargar, volvía a 0:
  /// el siguiente jugador repetía un id ya usado (corrección C1).
  String _nuevoId() {
    final est = estado!;
    final id = 'p${est.siguienteIdJugador.toString().padLeft(4, '0')}';
    est.siguienteIdJugador++;
    return id;
  }

  // ------------------- CONSULTAS BÁSICAS -------------------

  bool get hayPartida => estado != null;
  Agente get agente => estado!.agente;
  List<Jugador> get jugadores => estado!.jugadores;
  List<Equipo> get equipos => estado!.equipos;
  List<Noticia> get noticias => estado!.noticias;
  List<Competicion> get competiciones => estado!.competiciones;
  int get semana => estado!.semana;
  int get temporada => estado!.temporada;
  bool get finDelJuego => estado?.finDelJuego ?? false;

  /// ¿Hay una ceremonia de premios pendiente de mostrar?
  bool get ceremoniaPendiente => estado?.ceremoniaPendiente ?? false;

  /// Frecuencia de eventos elegida en Ajustes (Parte 2E).
  FrecuenciaEventos get frecuenciaEventos =>
      FrecuenciaEventos.porNombre(estado?.frecuenciaEventos);

  /// Semanas que quedan con un inversor activo.
  int get semanasInversor => estado?.semanasInversor ?? 0;

  /// Semanas que quedan con el contacto en un equipo grande activo.
  int get semanasContactoGrande => estado?.semanasContactoGrande ?? 0;

  /// Torneos internacionales de la temporada en curso.
  List<Torneo> get torneosDeTemporada =>
      estado!.torneos.where((t) => t.temporada == estado!.temporada).toList();

  /// Palmarés (títulos) de un videojuego.
  List<RegistroCampeon> palmaresDeJuego(Juego juego) =>
      estado!.palmares.where((r) => r.juego == juego).toList();

  /// Títulos ganados por un equipo.
  List<RegistroCampeon> titulosDeEquipo(String equipoId) =>
      estado!.palmares.where((r) => r.ganadorId == equipoId).toList();

  /// Premios individuales ganados por un jugador.
  List<PremioIndividual> premiosDeJugador(String jugadorId) =>
      estado!.premios.where((p) => p.jugadorId == jugadorId).toList();

  /// El torneo de un videojuego y clase en la temporada en curso (o null).
  Torneo? torneoDe(Juego juego, TipoTorneo tipo) {
    for (final t in estado!.torneos) {
      if (t.juego == juego &&
          t.tipo == tipo &&
          t.temporada == estado!.temporada) {
        return t;
      }
    }
    return null;
  }

  /// Los jugadores que yo represento.
  List<Jugador> get misJugadores =>
      estado!.jugadores.where((j) => j.representadoPorMi).toList();

  /// Mis 3 jugadores más valiosos (para el resumen).
  List<Jugador> get misMejoresJugadores {
    final lista = estado!.jugadores.where((j) => j.representadoPorMi).toList()
      ..sort((a, b) => b.valorMercado.compareTo(a.valorMercado));
    return lista.take(3).toList();
  }

  /// Las últimas 5 noticias.
  List<Noticia> get ultimasNoticias => estado!.noticias.take(5).toList();

  /// Ofertas pendientes de respuesta (traspasos y renovaciones).
  List<Oferta> get ofertasPendientes => estado?.ofertas ?? const [];

  /// Eventos aleatorios pendientes de resolver (Parte 2E).
  List<EventoPendiente> get eventosPendientes =>
      estado?.eventosPendientes ?? const [];

  /// Ofertas pendientes por un jugador concreto.
  List<Oferta> ofertasDe(String jugadorId) =>
      estado!.ofertas.where((o) => o.jugadorId == jugadorId).toList();

  /// Titulares (los que no son suplentes) de un equipo.
  List<Jugador> titularesDe(String equipoId) => estado!.jugadores
      .where((j) => j.equipoId == equipoId && !j.suplente)
      .toList();

  /// Suplentes de un equipo.
  List<Jugador> suplentesDe(String equipoId) => estado!.jugadores
      .where((j) => j.equipoId == equipoId && j.suplente)
      .toList();

  /// Busca un jugador por su id.
  Jugador? jugadorPorId(String id) => _indiceJugadores[id];

  /// Busca un equipo por su id.
  Equipo? equipoPorId(String id) => _indiceEquipos[id];

  /// Los equipos de un videojuego.
  List<Equipo> equiposDeJuego(Juego juego) =>
      estado!.equipos.where((e) => e.juego == juego).toList();

  /// Las regiones que existen en un videojuego (sin repetir).
  List<String> regionesDeJuego(Juego juego) {
    final regiones = <String>[];
    for (final equipo in estado!.equipos) {
      if (equipo.juego == juego && !regiones.contains(equipo.region)) {
        regiones.add(equipo.region);
      }
    }
    return regiones;
  }

  /// Los equipos de un videojuego y una región.
  List<Equipo> equiposDeRegion(Juego juego, String region) => estado!.equipos
      .where((e) => e.juego == juego && e.region == region)
      .toList();

  /// Los equipos de un videojuego, una región y una división.
  List<Equipo> equiposDeRegionYDivision(
    Juego juego,
    String region,
    int division,
  ) => estado!.equipos
      .where(
        (e) => e.juego == juego && e.region == region && e.division == division,
      )
      .toList();

  /// Devuelve la liga de un videojuego, región y división (o null).
  Competicion? competicion(Juego juego, String region, int division) {
    for (final comp in estado!.competiciones) {
      if (comp.juego == juego &&
          comp.region == region &&
          comp.division == division) {
        return comp;
      }
    }
    return null;
  }

  /// Etapa que se juega en la semana actual.
  Etapa get etapaActual => etapaDeSemana(estado!.semana);

  /// Próximos partidos de los equipos donde juegan mis representados.
  List<PartidoProgramado> get proximosPartidosDeMisJugadores {
    final est = estado!;
    // Split según la semana (antes del parón: Split 1; después: Split 2).
    final split = est.semana <= 20 ? 1 : 2;

    final resultado = <PartidoProgramado>[];
    for (final comp in est.competiciones) {
      final misEquipos = <String>{};
      for (final j in est.jugadores) {
        if (j.representadoPorMi &&
            j.equipoId != null &&
            comp.equipoIds.contains(j.equipoId)) {
          misEquipos.add(j.equipoId!);
        }
      }
      if (misEquipos.isEmpty) continue;

      final jugadas = comp.resultadosDeSplit(split).map((r) => r.fecha).toSet();
      final siguiente = jugadas.length + 1;
      final fechas = generarFechas(comp.equipoIds);
      if (siguiente < 1 || siguiente > fechas.length) continue;

      for (final serie in fechas[siguiente - 1]) {
        final local = serie.$1;
        final visitante = serie.$2;
        final miEquipo = misEquipos.contains(local)
            ? local
            : (misEquipos.contains(visitante) ? visitante : null);
        if (miEquipo == null) continue;
        final rival = miEquipo == local ? visitante : local;
        final misJugadores = est.jugadores
            .where((j) => j.representadoPorMi && j.equipoId == miEquipo)
            .toList();
        resultado.add(
          PartidoProgramado(
            competicion: comp,
            fecha: siguiente,
            miEquipoId: miEquipo,
            rivalId: rival,
            misJugadores: misJugadores,
          ),
        );
      }
    }
    return resultado;
  }

  /// Reconstruye los índices de jugadores y equipos por id.
  void _reconstruirIndices() {
    final est = estado!;
    // Además corrige nicks repetidos de partidas viejas o de datos iniciales:
    // el primero conserva el nombre y los demás reciben un número.
    asegurarNicksUnicos(est.jugadores);
    _indiceJugadores.clear();
    _indiceEquipos.clear();
    var siguiente = est.siguienteIdJugador;
    for (final j in est.jugadores) {
      _indiceJugadores[j.id] = j;
      // Recupera el contador en partidas v3–v6, que no lo guardaban, o si el
      // valor guardado se quedó atrás. Así el próximo id `p####` no repite.
      if (j.id.startsWith('p')) {
        final numero = int.tryParse(j.id.substring(1));
        if (numero != null && numero >= siguiente) {
          siguiente = numero + 1;
        }
      }
    }
    est.siguienteIdJugador = siguiente;
    for (final e in est.equipos) {
      _indiceEquipos[e.id] = e;
    }
  }

  /// Construye una liga por cada combinación videojuego + región + división.
  List<Competicion> _crearCompeticiones(List<Equipo> equipos) {
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

  // ------------------- CREAR / CARGAR / BORRAR -------------------

  /// Crea una partida nueva con el nombre y país del agente.
  /// El mundo (equipos, regiones y jugadores) se carga desde los JSON.
  Future<void> nuevaPartida({
    required String nombre,
    required String pais,
  }) async {
    final mundo = await CargadorMundo(_rnd).cargar();
    estado = EstadoPartida(
      agente: Agente(nombre: nombre, pais: pais),
      jugadores: mundo.jugadores,
      equipos: mundo.equipos,
      noticias: [],
      competiciones: _crearCompeticiones(mundo.equipos),
    );
    _reconstruirIndices();
    _agregarNoticia(
      '¡Bienvenido, $nombre! Tu carrera como agente comienza hoy.',
      TipoNoticia.evento,
    );
    await _guardarYNotificar();
  }

  /// Carga la partida guardada.
  Future<ResultadoCarga> cargar() async {
    final carga = await cargarPartida();
    if (carga.resultado != ResultadoCarga.ok || carga.estado == null) {
      return carga.resultado;
    }
    estado = carga.estado;
    _reconstruirIndices();
    _recalcularValores();
    // Al cargar se guarda de nuevo: así una partida vieja se actualiza al
    // formato actual (v7) con el contador de ids ya reconstruido.
    await guardarPartida(estado!);
    notifyListeners();
    return ResultadoCarga.ok;
  }

  /// Borra la partida guardada.
  Future<void> borrar() async {
    await borrarPartida();
    estado = null;
    _indiceJugadores.clear();
    _indiceEquipos.clear();
    // No se avisa a las pantallas después de dejar `estado` a null: sus
    // getters necesitan una partida y podían lanzar una excepción (C2).
    // Las pantallas que borran navegan al inicio justo después.
  }

  // ------------------- ACCIONES DEL AGENTE -------------------

  /// Recluta (representa) a un jugador. Cobra el 5% de su valor.
  Future<ResultadoAccion> reclutar(Jugador jugador) async {
    final ag = agente;
    if (jugador.representadoPorMi) {
      return ResultadoAccion(false, 'Ya representas a ${jugador.nick}.');
    }
    if (!aceptaRepresentacion(
      reputacion: ag.reputacion,
      habilidad: jugador.habilidad,
    )) {
      return ResultadoAccion(
        false,
        '${jugador.nick} prefiere un agente con más prestigio.',
      );
    }
    final costo = costoRepresentar(jugador.valorMercado);
    if (ag.dinero < costo) {
      return ResultadoAccion(
        false,
        'No tienes dinero suficiente (necesitas ${formatearDinero(costo)}).',
      );
    }
    ag.dinero -= costo;
    jugador.representadoPorMi = true;
    // El periodo mínimo de representación empieza de cero (corrección I1).
    jugador.semanasRepresentado = 0;
    _agregarNoticia(
      'Reclutaste a ${jugador.nick} por ${formatearDinero(costo)}.',
      TipoNoticia.fichaje,
    );
    await _guardarYNotificar();
    return ResultadoAccion(true, 'Ahora representas a ${jugador.nick}.');
  }

  /// Deja de representar a un jugador.
  Future<ResultadoAccion> dejarDeRepresentar(Jugador jugador) async {
    jugador.representadoPorMi = false;
    jugador.semanasRepresentado = 0;
    // Las ofertas pendientes por este jugador dejan de tener sentido (I6).
    _invalidarOfertasObsoletas();
    _agregarNoticia(
      'Dejaste de representar a ${jugador.nick}.',
      TipoNoticia.evento,
    );
    await _guardarYNotificar();
    return ResultadoAccion(true, 'Ya no representas a ${jugador.nick}.');
  }

  // ------------------- NEGOCIACIÓN -------------------

  /// Calcula el interés de un equipo por un jugador.
  NivelInteres interesDe(Jugador jugador, Equipo equipo) {
    if (!equipoInteresado(
      habilidad: jugador.habilidad,
      prestigio: equipo.prestigio,
    )) {
      return NivelInteres.sinInteres;
    }
    if (jugador.habilidad >= equipo.prestigio) {
      return NivelInteres.muyInteresado;
    }
    return NivelInteres.interesado;
  }

  /// Rondas de negociación que quedan entre un jugador y un equipo.
  int rondasRestantes(Jugador jugador, Equipo equipo) {
    final clave = EstadoPartida.clavePar(jugador.id, equipo.id);
    final usadas = estado!.rondasNegociacion[clave] ?? 0;
    return maxRondasNegociacion - usadas;
  }

  /// ¿Está bloqueado el par jugador+equipo hasta la próxima temporada?
  bool bloqueado(Jugador jugador, Equipo equipo) {
    final clave = EstadoPartida.clavePar(jugador.id, equipo.id);
    return estado!.paresBloqueados.contains(clave);
  }

  /// Envía una oferta de un jugador a un equipo.
  Future<ResultadoOferta> ofrecer({
    required Jugador jugador,
    required Equipo equipo,
    required int precioPedido,
  }) async {
    if (!jugador.representadoPorMi) {
      return ResultadoOferta(
        respuesta: RespuestaEquipo.rechaza,
        mensaje: 'Solo puedes ofrecer jugadores de tu agencia.',
      );
    }
    // Debes representarlo un tiempo mínimo antes de ofrecerlo (I1): así no
    // se puede reclutar y revender en la misma semana para cobrar comisión.
    if (jugador.semanasRepresentado < semanasMinimasRepresentacion) {
      final faltan =
          semanasMinimasRepresentacion - jugador.semanasRepresentado;
      return ResultadoOferta(
        respuesta: RespuestaEquipo.sinInteres,
        mensaje:
            'Aún no puedes ofrecer a ${jugador.nick}: llevas '
            '${jugador.semanasRepresentado} de $semanasMinimasRepresentacion '
            'semanas como su agente. Espera $faltan semana'
            '${faltan == 1 ? '' : 's'}.',
      );
    }
    if (jugador.juego != equipo.juego) {
      return ResultadoOferta(
        respuesta: RespuestaEquipo.sinInteres,
        mensaje: 'El jugador y el equipo deben ser del mismo videojuego.',
      );
    }
    // No tiene sentido "vender" a un jugador a su propio club: generaría una
    // comisión y reputación sin ningún traspaso real (C6).
    if (jugador.equipoId == equipo.id) {
      return ResultadoOferta(
        respuesta: RespuestaEquipo.sinInteres,
        mensaje:
            '${equipo.nombre} ya tiene a ${jugador.nick}: no puedes venderlo '
            'a su propio club.',
      );
    }
    // Un jugador recién traspasado no puede volver a venderse hasta la
    // próxima temporada (corrección 2.5 A2).
    if (jugador.bloqueadoTraspaso(estado!.temporada)) {
      return ResultadoOferta(
        respuesta: RespuestaEquipo.sinInteres,
        mensaje:
            '${jugador.nick} acaba de cambiar de equipo: podrá negociar de '
            'nuevo la próxima temporada.',
      );
    }
    final clave = EstadoPartida.clavePar(jugador.id, equipo.id);
    if (estado!.paresBloqueados.contains(clave)) {
      return ResultadoOferta(
        respuesta: RespuestaEquipo.sinInteres,
        mensaje:
            '${equipo.nombre} ya no quiere negociar hasta la próxima temporada.',
      );
    }
    if (rondasRestantes(jugador, equipo) <= 0) {
      estado!.paresBloqueados.add(clave);
      await _guardarYNotificar();
      return ResultadoOferta(
        respuesta: RespuestaEquipo.sinInteres,
        mensaje: 'Se acabaron las rondas con ${equipo.nombre}.',
      );
    }
    if (!equipoInteresado(
      habilidad: jugador.habilidad,
      prestigio: equipo.prestigio,
    )) {
      return ResultadoOferta(
        respuesta: RespuestaEquipo.sinInteres,
        mensaje: '${equipo.nombre} no está interesado en ${jugador.nick}.',
      );
    }
    if (jugador.valorMercado > equipo.presupuesto) {
      return ResultadoOferta(
        respuesta: RespuestaEquipo.sinPresupuesto,
        mensaje: '${equipo.nombre} no tiene presupuesto suficiente.',
      );
    }

    // Consumo una ronda de negociación.
    estado!.rondasNegociacion[clave] =
        (estado!.rondasNegociacion[clave] ?? 0) + 1;

    // El contacto con un equipo grande da más margen solo en equipos de élite.
    final margenContacto =
        estado!.semanasContactoGrande > 0 && equipo.prestigio >= 85
        ? eventos.margenContactoGrande
        : 0.0;

    final resultado = calcularRespuesta(
      precioPedido: precioPedido,
      valorMercado: jugador.valorMercado,
      rnd: _rnd,
      margenExtraAceptacion: margenContacto,
    );

    if (resultado.respuesta == RespuestaEquipo.acepta) {
      // Validación final antes de mover dinero: el comprador debe poder pagar
      // el precio aceptado y el jugador debe seguir en su club (C4/C6).
      final motivo = _motivoTraspasoInvalido(
        jugador: jugador,
        equipo: equipo,
        precio: precioPedido,
        // `ofrecer` ya se usa desde la pantalla, que controla la ventana.
        // Aquí solo se valida el dinero y la situación del jugador.
        comprobarVentana: false,
      );
      if (motivo != null) {
        return ResultadoOferta(
          respuesta: RespuestaEquipo.sinPresupuesto,
          mensaje: motivo,
        );
      }
      await _cerrarTrato(jugador, equipo, precioPedido);
    } else {
      if (resultado.respuesta == RespuestaEquipo.rechaza &&
          rondasRestantes(jugador, equipo) <= 0) {
        estado!.paresBloqueados.add(clave);
      }
      await _guardarYNotificar();
    }
    return resultado;
  }

  /// Acepta una contraoferta del equipo y cierra el trato.
  Future<ResultadoAccion> aceptarContraoferta({
    required Jugador jugador,
    required Equipo equipo,
    required int precio,
  }) async {
    // Las mismas reglas que al aceptar una oferta entrante (C4/C6): el
    // jugador debe seguir siendo mío, no puede irse a su propio club y el
    // comprador debe poder pagar.
    final motivo = _motivoTraspasoInvalido(
      jugador: jugador,
      equipo: equipo,
      precio: precio,
    );
    if (motivo != null) return ResultadoAccion(false, motivo);
    await _cerrarTrato(jugador, equipo, precio);
    return ResultadoAccion(true, 'Trato cerrado con ${equipo.nombre}.');
  }

  /// Devuelve el motivo por el que un traspaso ya no se puede cerrar, o null
  /// si es válido. Centraliza las comprobaciones de C4 y C6:
  /// - la oferta (si existe) sigue pendiente;
  /// - el jugador sigue representado y en el club de origen;
  /// - el comprador es de otro club y del mismo videojuego;
  /// - el mercado está abierto (salvo agentes libres);
  /// - el jugador no está bloqueado por un traspaso reciente;
  /// - el comprador tiene presupuesto para pagar el precio.
  String? _motivoTraspasoInvalido({
    Oferta? oferta,
    required Jugador jugador,
    required Equipo equipo,
    required int precio,
    bool comprobarVentana = true,
  }) {
    final est = estado!;
    if (oferta != null && !est.ofertas.contains(oferta)) {
      return 'La oferta ya no está disponible.';
    }
    if (!jugador.representadoPorMi) {
      return 'Ya no representas a ${jugador.nick}.';
    }
    if (equipo.id == jugador.equipoId) {
      return '${equipo.nombre} ya tiene a ${jugador.nick}: no puedes venderlo '
          'a su propio club.';
    }
    if (equipo.juego != jugador.juego) {
      return 'El jugador y el equipo deben ser del mismo videojuego.';
    }
    final origen = oferta?.equipoOrigenId;
    if (origen != null && jugador.equipoId != origen) {
      return '${jugador.nick} ya no está en el club de origen de la oferta.';
    }
    if (comprobarVentana &&
        jugador.equipoId != null &&
        !enVentanaFichajes(est.semana)) {
      return 'El mercado está cerrado. ${proximaVentanaTexto(est.semana)}';
    }
    if (jugador.bloqueadoTraspaso(est.temporada)) {
      return '${jugador.nick} acaba de cambiar de equipo: podrá negociar de '
          'nuevo la próxima temporada.';
    }
    if (precio <= 0) {
      return 'El importe de la oferta no es válido.';
    }
    if (equipo.presupuesto < precio) {
      return '${equipo.nombre} no tiene presupuesto suficiente para pagar '
          '${formatearDinero(precio)}.';
    }
    return null;
  }

  /// Cierra la transferencia: paga la comisión, actualiza el equipo, etc.
  ///
  /// [salarioAnual] es el salario que ofreció el comprador. Si no se indica,
  /// se calcula a partir del valor de mercado (I7).
  Future<void> _cerrarTrato(
    Jugador jugador,
    Equipo equipo,
    int precio, {
    int? salarioAnual,
  }) async {
    final ag = agente;
    final origenId = jugador.equipoId;

    // El club vendedor recibe el precio menos la comisión del agente (I2).
    // La comisión que se descuenta es la bruta del 10 %: el inversor, si lo
    // hay, se lleva su parte de MI comisión, no del club vendedor.
    final comisionBruta = comisionPorTransferencia(precio);
    var vendedor = origenId == null ? null : _indiceEquipos[origenId];
    if (vendedor == null && origenId != null) {
      for (final posible in estado!.equipos) {
        if (posible.id == origenId) {
          vendedor = posible;
          break;
        }
      }
    }
    if (vendedor != null && vendedor.id != equipo.id) {
      vendedor.presupuesto += precio - comisionBruta;
    }

    // El jugador desplazado en ese rol baja a suplente (no queda libre).
    for (final otro in estado!.jugadores) {
      if (otro.id != jugador.id &&
          otro.equipoId == equipo.id &&
          otro.rol == jugador.rol &&
          !otro.suplente) {
        otro.suplente = true;
        _agregarNoticia(
          '${otro.nick} pasa a suplente tras la llegada de ${jugador.nick} a ${equipo.nombre}.',
          TipoNoticia.evento,
        );
      }
    }
    // Si el equipo supera el máximo de suplentes, el más débil queda libre.
    for (final sobrante in recortarSuplentes(estado!, equipo)) {
      _agregarNoticia(
        '${sobrante.nick} quedó libre para hacer sitio en ${equipo.nombre}.',
        TipoNoticia.evento,
      );
    }

    final comision = _comisionNeta(comisionPorTransferencia(precio));
    ag.dinero += comision;
    // La validación previa garantiza que el comprador tiene este dinero.
    equipo.presupuesto -= precio;

    jugador.equipoId = equipo.id;
    jugador.suplente = false;
    jugador.semanasContrato = 52 + _rnd.nextInt(53);
    jugador.semanasComoSuplente = 0;
    // El salario prometido en la oferta se aplica de verdad (I7).
    jugador.salarioAnual =
        salarioAnual ?? calcularSalarioAnual(jugador.valorMercado);
    // Queda bloqueado para otro traspaso hasta la próxima temporada.
    jugador.temporadaUltimoTraspaso = estado!.temporada;

    // Reputación: cada traspaso cerrado suma. Un equipo de élite
    // (prestigio ≥ 85) da más visibilidad que uno normal. Antes era +1/+3 y
    // los eventos negativos podían dejar la reputación estancada o bajando.
    final reputacionGanada = reputacionPorTraspaso(
      reputacionActual: ag.reputacion,
      elite: equipo.prestigio >= 85,
    );
    ag.reputacion = min(100, ag.reputacion + reputacionGanada);

    _agregarNoticia(
      '${jugador.nick} fue transferido a ${equipo.nombre} por ${formatearDinero(precio)}. '
      'Tu comisión: ${formatearDinero(comision)}.',
      TipoNoticia.venta,
    );

    // Si el equipo de origen se queda sin titular en ese rol, se repone.
    if (origenId != null && origenId != equipo.id) {
      _reponerTitular(origenId, jugador.rol);
    }

    final clave = EstadoPartida.clavePar(jugador.id, equipo.id);
    estado!.rondasNegociacion.remove(clave);
    // Cualquier otra oferta por este jugador quedó obsoleta al cambiar de
    // club (corrección I6).
    _invalidarOfertasObsoletas();
    await _guardarYNotificar();
  }

  /// Quita las ofertas que ya no representan la situación actual del jugador.
  ///
  /// Se invalida una oferta si el jugador ya no existe, dejó de ser mío,
  /// cambió de club o de videojuego, el comprador no puede pagar o (en las
  /// renovaciones) el contrato ya no está vigente (corrección I6).
  void _invalidarOfertasObsoletas() {
    final est = estado!;
    // Algunas pruebas (y partidas restauradas a mano) asignan `estado` sin
    // pasar por `cargar`. Si los índices están vacíos, se reconstruyen para
    // no borrar ofertas válidas por error.
    if (_indiceJugadores.isEmpty && est.jugadores.isNotEmpty) {
      _reconstruirIndices();
    }
    if (_indiceEquipos.isEmpty && est.equipos.isNotEmpty) {
      for (final equipo in est.equipos) {
        _indiceEquipos[equipo.id] = equipo;
      }
    }
    est.ofertas.removeWhere((oferta) {
      final jugador = _indiceJugadores[oferta.jugadorId];
      if (jugador == null) return true;
      if (!jugador.representadoPorMi) return true;
      final equipo = _indiceEquipos[oferta.equipoId];
      if (equipo == null) return true;

      if (oferta.tipo == TipoOferta.renovacion) {
        return jugador.equipoId != oferta.equipoId ||
            jugador.semanasContrato <= 0;
      }

      if (equipo.id == jugador.equipoId) return true;
      if (equipo.juego != jugador.juego) return true;
      final origen = oferta.equipoOrigenId;
      if (origen != null && jugador.equipoId != origen) return true;
      if (equipo.presupuesto < oferta.monto) return true;
      // Recién traspasado: la oferta nació antes de ese cambio o ya no vale.
      if (jugador.bloqueadoTraspaso(est.temporada)) return true;
      return false;
    });
  }

  // ------------------- MERCADO, OFERTAS Y SUPLENTES -------------------

  /// Procesa los fichajes automáticos de la IA en la semana actual.
  void _procesarMercadoIA() {
    final est = estado!;
    final resultado = procesarMercadoIA(
      estado: est,
      indiceEquipos: _indiceEquipos,
      indiceJugadores: _indiceJugadores,
      rnd: _rnd,
      nuevoIdJugador: _nuevoId,
    );
    metricas.fichajesIA += resultado.fichajesCerrados;
    metricas.fichajesVentana += resultado.fichajesCerrados;
    metricas.ofertasIA += resultado.ofertas.length;
    metricas.ofertasVentana += resultado.ofertas.length;
    for (final texto in resultado.noticias) {
      _agregarNoticia(texto, TipoNoticia.fichaje);
    }
    for (final oferta in resultado.ofertas) {
      final jugador = _indiceJugadores[oferta.jugadorId];
      final equipo = _indiceEquipos[oferta.equipoId];
      if (jugador != null && equipo != null) {
        _agregarNoticia(
          '${equipo.nombre} ofrece ${formatearDinero(oferta.monto)} por ${jugador.nick}.',
          TipoNoticia.venta,
        );
      }
    }
  }

  /// Revisa las renovaciones (todas las semanas): ofertas a mis jugadores
  /// y renovaciones automáticas de la IA.
  void _procesarRenovaciones() {
    final est = estado!;
    final ofertas = generarRenovaciones(
      estado: est,
      indiceEquipos: _indiceEquipos,
      rnd: _rnd,
    );
    for (final oferta in ofertas) {
      final jugador = _indiceJugadores[oferta.jugadorId];
      final equipo = _indiceEquipos[oferta.equipoId];
      if (jugador != null && equipo != null) {
        _agregarNoticia(
          '${equipo.nombre} quiere renovar a ${jugador.nick} '
          '(nuevo salario ${formatearDinero(oferta.monto)}).',
          TipoNoticia.evento,
        );
      }
    }
    renovacionesAutomaticasIA(estado: est, rnd: _rnd);
  }

  /// Baja las semanas de las ofertas de traspaso y elimina las vencidas.
  void _avanzarOfertas() {
    final est = estado!;
    final vencidas = <Oferta>[];
    final invalidas = <Oferta>[];
    for (final oferta in est.ofertas) {
      if (oferta.tipo == TipoOferta.traspaso) {
        // Una oferta creada esta misma semana no descuenta tiempo todavía:
        // así el agente dispone de las 2 semanas que se le prometen.
        final recienCreada =
            oferta.temporada == est.temporada && oferta.semana == est.semana;
        if (recienCreada) continue;
        oferta.semanasRestantes--;
        if (oferta.semanasRestantes <= 0) vencidas.add(oferta);
      } else {
        final jugador = _indiceJugadores[oferta.jugadorId];
        final vigente =
            jugador != null &&
            jugador.equipoId == oferta.equipoId &&
            jugador.semanasContrato > 0;
        if (!vigente) invalidas.add(oferta);
      }
    }
    est.ofertas.removeWhere(
      (o) => vencidas.contains(o) || invalidas.contains(o),
    );
    // Además, cualquier oferta que haya quedado obsoleta por un cambio de
    // club, de videojuego, de agencia o de presupuesto se elimina (I6).
    _invalidarOfertasObsoletas();
    for (final oferta in vencidas) {
      final jugador = _indiceJugadores[oferta.jugadorId];
      if (jugador != null) {
        _agregarNoticia(
          'La oferta por ${jugador.nick} venció sin respuesta.',
          TipoNoticia.alerta,
        );
      }
    }
  }

  /// Suma una semana a los suplentes dentro de un split (o resetea fuera).
  void _actualizarContadoresSuplentes() {
    final est = estado!;
    final enSplit =
        (est.semana >= 5 && est.semana <= 18) ||
        (est.semana >= 27 && est.semana <= 40);
    for (final j in est.jugadores) {
      if (enSplit && j.equipoId != null && j.suplente) {
        j.semanasComoSuplente++;
      } else {
        j.semanasComoSuplente = 0;
      }
    }
  }

  /// Castiga con −10 de moral a quien fue suplente todo un split.
  void _castigarSuplentesDeSplit() {
    for (final j in estado!.jugadores) {
      if (j.equipoId == null || !j.suplente) continue;
      if (j.semanasComoSuplente < semanasPorSplit) continue;
      j.moral = (j.moral + castigoMoralSuplenteSplit).clamp(0, 100);
      if (j.representadoPorMi) {
        _agregarNoticia(
          '${j.nick} pasó todo el split en el banquillo y pierde moral.',
          TipoNoticia.alerta,
        );
      }
    }
  }

  /// Reorganiza la plantilla de cada equipo: en cada rol juega el mejor y el
  /// resto son suplentes (máximo dos por equipo).
  void _reorganizarTitulares() {
    final est = estado!;
    for (final equipo in est.equipos) {
      final plantilla = est.jugadores
          .where((j) => j.equipoId == equipo.id)
          .toList();
      final porRol = <String, List<Jugador>>{};
      for (final j in plantilla) {
        porRol.putIfAbsent(j.rol, () => <Jugador>[]).add(j);
      }
      for (final grupo in porRol.values) {
        grupo.sort((a, b) => b.habilidad.compareTo(a.habilidad));
        for (var i = 0; i < grupo.length; i++) {
          grupo[i].suplente = i > 0;
          if (i == 0) grupo[i].semanasComoSuplente = 0;
        }
      }
      for (final sobrante in recortarSuplentes(est, equipo)) {
        _agregarNoticia(
          '${sobrante.nick} quedó libre al recortar la plantilla de ${equipo.nombre}.',
          TipoNoticia.evento,
        );
      }
    }
  }

  /// Si un equipo se quedó sin titular en un rol, genera un reemplazo.
  void _reponerTitular(String equipoId, String rol) {
    final reemplazo = generarReemplazoSiFalta(
      estado: estado!,
      indiceEquipos: _indiceEquipos,
      rnd: _rnd,
      nuevoIdJugador: _nuevoId,
      equipoId: equipoId,
      rol: rol,
    );
    if (reemplazo != null) {
      _indiceJugadores[reemplazo.id] = reemplazo;
    }
  }

  // ------------------- RESPUESTA A OFERTAS -------------------

  /// Acepta una oferta: cierra el traspaso o aplica la renovación.
  Future<ResultadoAccion> aceptarOferta(Oferta oferta) async {
    final est = estado!;
    // La oferta debe seguir pendiente. Esto también evita que un doble toque
    // en "Aceptar" cobre dos comisiones por la misma renovación (C4).
    if (!est.ofertas.contains(oferta)) {
      return ResultadoAccion(false, 'La oferta ya no está disponible.');
    }
    final jugador = _indiceJugadores[oferta.jugadorId];
    final equipo = _indiceEquipos[oferta.equipoId];
    if (jugador == null || equipo == null) {
      est.ofertas.remove(oferta);
      await _guardarYNotificar();
      return ResultadoAccion(false, 'La oferta ya no es válida.');
    }
    if (oferta.tipo == TipoOferta.traspaso) {
      final motivo = _motivoTraspasoInvalido(
        oferta: oferta,
        jugador: jugador,
        equipo: equipo,
        precio: oferta.monto,
      );
      if (motivo != null) {
        est.ofertas.remove(oferta);
        await _guardarYNotificar();
        return ResultadoAccion(false, motivo);
      }
      await _cerrarTrato(
        jugador,
        equipo,
        oferta.monto,
        salarioAnual: oferta.salarioAnual,
      );
      est.ofertas.remove(oferta);
      await _guardarYNotificar();
      return ResultadoAccion(
        true,
        'Aceptaste vender a ${jugador.nick} a ${equipo.nombre}.',
      );
    }

    // Renovación de contrato: el jugador debe seguir representado y en el
    // mismo club, con contrato vigente.
    if (!jugador.representadoPorMi ||
        jugador.equipoId != oferta.equipoId ||
        jugador.semanasContrato <= 0) {
      est.ofertas.remove(oferta);
      await _guardarYNotificar();
      return ResultadoAccion(false, 'La oferta de renovación ya no es válida.');
    }
    jugador.salarioAnual = oferta.monto;
    jugador.semanasContrato = 52 + _rnd.nextInt(53);
    final comision = _comisionNeta((oferta.monto * comisionRenovacion).round());
    agente.dinero += comision;
    est.ofertas.remove(oferta);
    _agregarNoticia(
      'Renovaste a ${jugador.nick} con ${equipo.nombre}. '
      'Tu comisión: ${formatearDinero(comision)}.',
      TipoNoticia.venta,
    );
    await _guardarYNotificar();
    return ResultadoAccion(true, 'Renovación aceptada.');
  }

  /// Rechaza una oferta. Si era de renovación, el jugador quedará libre.
  Future<ResultadoAccion> rechazarOferta(Oferta oferta) async {
    final est = estado!;
    if (!est.ofertas.contains(oferta)) {
      return ResultadoAccion(false, 'La oferta ya no está disponible.');
    }
    final jugador = _indiceJugadores[oferta.jugadorId];
    final equipo = _indiceEquipos[oferta.equipoId];
    est.ofertas.remove(oferta);
    if (jugador != null && equipo != null) {
      if (oferta.tipo == TipoOferta.renovacion) {
        _agregarNoticia(
          'Rechazaste la renovación de ${equipo.nombre} para ${jugador.nick}; '
          'quedará libre al terminar su contrato.',
          TipoNoticia.alerta,
        );
      } else {
        _agregarNoticia(
          'Rechazaste la oferta de ${equipo.nombre} por ${jugador.nick}.',
          TipoNoticia.evento,
        );
      }
    }
    await _guardarYNotificar();
    return ResultadoAccion(true, 'Oferta rechazada.');
  }

  /// Pide más dinero por una oferta de traspaso. El equipo puede subirla o
  /// retirarla, pero hay un máximo de mejoras y un tope de importe (C5).
  Future<ResultadoAccion> pedirMasOferta(Oferta oferta) async {
    final est = estado!;
    if (!est.ofertas.contains(oferta)) {
      return ResultadoAccion(false, 'La oferta ya no está disponible.');
    }
    if (oferta.tipo != TipoOferta.traspaso) {
      return ResultadoAccion(
        false,
        'Solo puedes pedir más en una oferta de traspaso.',
      );
    }
    final jugador = _indiceJugadores[oferta.jugadorId];
    final equipo = _indiceEquipos[oferta.equipoId];
    if (jugador == null || equipo == null) {
      est.ofertas.remove(oferta);
      await _guardarYNotificar();
      return ResultadoAccion(false, 'La oferta ya no es válida.');
    }

    // Oferta obsoleta: el jugador cambió de club, dejó de ser mío o el
    // comprador ya no puede pagar. No se mejora una oferta irreal (C4).
    final origen = oferta.equipoOrigenId;
    final obsoleta =
        !jugador.representadoPorMi ||
        equipo.id == jugador.equipoId ||
        equipo.juego != jugador.juego ||
        (origen != null && jugador.equipoId != origen) ||
        jugador.bloqueadoTraspaso(est.temporada);
    if (obsoleta) {
      est.ofertas.remove(oferta);
      await _guardarYNotificar();
      return ResultadoAccion(false, 'La oferta ya no es válida.');
    }

    // Tope de mejoras: después de dos subidas el equipo ya no ofrece más y
    // la oferta mantiene su plazo original.
    if (oferta.mejorasRealizadas >= maxMejorasOferta) {
      return ResultadoAccion(
        false,
        '${equipo.nombre} ya no mejorará más su oferta por ${jugador.nick}.',
      );
    }

    if (_rnd.nextDouble() < probRetiradaPedirMas) {
      est.ofertas.remove(oferta);
      _agregarNoticia(
        '${equipo.nombre} retiró su oferta por ${jugador.nick}.',
        TipoNoticia.alerta,
      );
      await _guardarYNotificar();
      return ResultadoAccion(true, '${equipo.nombre} retiró la oferta.');
    }

    // El tope no puede superar ni el 140 % del valor ni el presupuesto del
    // comprador. Si una oferta vieja no lo guardó, se calcula ahora.
    final topeGuardado = oferta.montoMaximo > 0
        ? oferta.montoMaximo
        : topeMontoOferta(
            valorMercado: jugador.valorMercado,
            presupuesto: equipo.presupuesto,
          );
    final tope = min(topeGuardado, equipo.presupuesto);
    final factor =
        1 + pedirMasMin + _rnd.nextDouble() * (pedirMasMax - pedirMasMin);
    final propuesto = ((oferta.monto * factor) / 1000).round() * 1000;
    final nuevoMonto = min(propuesto, tope);
    if (nuevoMonto <= oferta.monto) {
      return ResultadoAccion(
        false,
        '${equipo.nombre} no puede subir más la oferta por ${jugador.nick}.',
      );
    }

    oferta.monto = nuevoMonto;
    oferta.mejorasRealizadas++;
    // No se reinicia `semanasRestantes`: la oferta conserva su plazo real.
    _agregarNoticia(
      '${equipo.nombre} sube su oferta por ${jugador.nick} a ${formatearDinero(oferta.monto)}.',
      TipoNoticia.evento,
    );
    await _guardarYNotificar();
    return ResultadoAccion(
      true,
      'Nueva oferta: ${formatearDinero(oferta.monto)}.',
    );
  }

  // ------------------- EVENTOS ALEATORIOS -------------------

  /// Resuelve un evento pendiente con la opción elegida (0 = A, 1 = B).
  /// El costo ya viene limitado por la lógica de eventos.
  Future<ResultadoAccion> resolverEvento(
    EventoPendiente evento,
    int opcion,
  ) async {
    final est = estado!;
    // Idempotencia (I4/I15): si el evento ya se resolvió (por un doble toque
    // o porque expiró), no se vuelve a aplicar su efecto ni su dinero.
    if (!est.eventosPendientes.contains(evento)) {
      return ResultadoAccion(false, 'El evento ya no está disponible.');
    }
    final resultado = eventos.resolverEvento(
      estado: est,
      indiceJugadores: _indiceJugadores,
      indiceEquipos: _indiceEquipos,
      rnd: _rnd,
      nuevoIdJugador: _nuevoId,
      evento: evento,
      opcion: opcion,
    );
    _agregarNoticia(resultado.noticia, resultado.tipoNoticia);
    if (resultado.reconstruirIndices) {
      _reconstruirIndices();
      _recalcularValores();
    }
    // Un evento puede liberar al jugador, cambiarle el videojuego o hacerle
    // perder la representación: las ofertas anteriores dejan de valer (I6).
    _invalidarOfertasObsoletas();
    await _guardarYNotificar();
    return ResultadoAccion(true, resultado.noticia);
  }

  /// Resuelve automáticamente los eventos informativos (sin decisión).
  /// Se usa al avanzar varias semanas para no abrir una ventana por cada uno.
  Future<void> resolverEventosInformativos() async {
    if (estado == null) return;
    final pendientes = estado!.eventosPendientes
        .where((evento) => !evento.esDecision)
        .toList();
    for (final evento in pendientes) {
      await resolverEvento(evento, 0);
    }
  }

  /// Cambia la frecuencia con la que aparecen los eventos aleatorios.
  Future<void> cambiarFrecuenciaEventos(FrecuenciaEventos frecuencia) async {
    if (estado == null) return;
    estado!.frecuenciaEventos = frecuencia.name;
    await _guardarYNotificar();
  }

  // ------------------- PASO DEL TIEMPO -------------------

  /// Genera los eventos aleatorios de la semana (Parte 2E).
  ///
  /// Los eventos de jugador y agencia quedan pendientes para la ventana
  /// emergente; los del mundo ya se aplicaron y solo dejan noticia.
  void _generarEventosSemana() {
    final est = estado!;
    final resultado = eventos.generarEventosSemana(
      estado: est,
      indiceJugadores: _indiceJugadores,
      indiceEquipos: _indiceEquipos,
      rnd: _rnd,
      nuevoIdJugador: _nuevoId,
    );
    metricas.eventosGenerados +=
        resultado.eventos.length + resultado.noticias.length;
    metricas.eventosConDecision += resultado.eventos
        .where((evento) => evento.esDecision)
        .length;
    for (final noticia in resultado.noticias) {
      _agregarNoticia(noticia.texto, noticia.tipo);
    }
    est.eventosPendientes.addAll(resultado.eventos);

    // Los eventos con decisión no pueden acumularse sin límite (I15). Si la
    // lista supera el máximo, los más antiguos expiran y quedan como noticia.
    final expirados = eventos.limitarEventosPendientes(est);
    for (final evento in expirados) {
      _agregarNoticia(
        'El evento "${evento.titulo}" expiró sin resolverse.',
        TipoNoticia.alerta,
      );
    }

    // Un evento del mundo puede retirar jugadores o reponer titulares.
    if (resultado.noticias.isNotEmpty) {
      _reconstruirIndices();
      _recalcularValores();
    }
  }

  /// Avanza una semana: cobra comisiones, gasta oficina, progresa jugadores,
  /// baja contratos y controla la bancarrota.
  Future<void> avanzarSemana() async {
    if (estado == null || _avanzando) return;
    _avanzando = true;
    // Avisa antes de empezar para que la interfaz desactive el botón (I5).
    notifyListeners();
    try {
      await _avanzarSemanaInterna();
    } finally {
      _avanzando = false;
      notifyListeners();
    }
  }

  /// Cuerpo real del avance de semana, sin el bloqueo de doble toque.
  Future<void> _avanzarSemanaInterna() async {
    final est = estado!;
    final ag = est.agente;
    var ingresos = 0;
    var gastos = 0;

    // Los contadores de simulación se reinician al cambiar de temporada o de
    // ventana de fichajes. No forman parte del guardado.
    metricas.asegurarTemporada(est.temporada);
    if (est.semana == 1 || est.semana == 23 || est.semana == 47) {
      metricas.reiniciarVentana();
    }

    // 0) Antes de avanzar, se simula la etapa de esta semana.
    _simularEtapaActual();

    // 1) Mercado y renovaciones. Las renovaciones se revisan TODAS las
    //    semanas; los traspasos de la IA solo en ventana de fichajes.
    if (enVentanaFichajes(est.semana)) {
      _procesarMercadoIA();
    }
    _procesarRenovaciones();

    // 2) Bajan las semanas de las ofertas pendientes (y vencen).
    _avanzarOfertas();

    // 3) Contadores de suplentes y castigo al terminar cada split.
    _actualizarContadoresSuplentes();
    if (est.semana == 18 || est.semana == 40) {
      _castigarSuplentesDeSplit();
    }

    // Cada 4 semanas, el valor de cada jugador sube o baja según su nota.
    if (est.semana % 4 == 0) {
      _ajustarValoresPorNota();
    }

    // 4) Una sola pasada por todos los jugadores (A3): comisión de salario,
    //    contrato, progreso e inactividad. Antes se recorrían cuatro veces
    //    la misma lista cada semana.
    gastos += gastoOficinaSemanal;
    final huecosPorContrato = <({String equipoId, String rol})>[];
    for (final j in est.jugadores) {
      // 4.0) Suma una semana de representación (corrección I1).
      if (j.representadoPorMi) j.semanasRepresentado++;

      // 4.1) Comisión por el salario de mis jugadores con equipo.
      if (j.representadoPorMi && j.equipoId != null) {
        final semanal = calcularSalarioSemanal(j.salarioAnual);
        ingresos += _comisionNeta((semanal * comisionSalario).round());
      }

      // 4.2) Baja el contrato; si llega a 0, el jugador queda libre.
      if (j.equipoId != null && j.semanasContrato > 0) {
        j.semanasContrato--;
        if (j.semanasContrato <= 0) {
          final equipoId = j.equipoId!;
          final rol = j.rol;
          final eraTitular = !j.suplente;
          j.equipoId = null;
          j.semanasContrato = 0;
          j.suplente = false;
          j.semanasComoSuplente = 0;
          _agregarNoticia(
            '${j.nick} quedó libre al terminar su contrato.',
            TipoNoticia.alerta,
          );
          // Si se va un titular, el equipo repone su rol en la misma semana.
          if (eraTitular) {
            huecosPorContrato.add((equipoId: equipoId, rol: rol));
          }
        }
      }

      // 4.3) Progreso semanal (mejora o empeora la habilidad).
      _progresarJugador(j);

      // 4.4) Baja la semana de inactividad (lesión o descanso).
      if (j.semanasInactivo > 0) j.semanasInactivo--;
    }
    for (final hueco in huecosPorContrato) {
      _reponerTitular(hueco.equipoId, hueco.rol);
    }

    // 8) Avanza la semana y, si toca, empieza una nueva temporada.
    est.semana++;
    // Al empezar un split se reorganizan titulares y suplentes.
    if (est.semana == 5 || est.semana == 27) {
      _reorganizarTitulares();
    }
    // Al empezar una nueva ventana se resetea el contador de fichajes.
    if (est.semana == 23 || est.semana == 47) {
      est.fichajesVentana.clear();
    }
    if (est.semana == 47) {
      _calcularPremiosTemporada();
    }
    if (est.semana > semanasPorTemporada) {
      _nuevaTemporada();
    }

    // 9) Aplico el dinero.
    ag.dinero += ingresos - gastos;

    // 10) Control de bancarrota.
    if (ag.dinero < 0) {
      ag.semanasEnNegativo++;
      if (ag.semanasEnNegativo >= semanasParaBancarrota) {
        est.finDelJuego = true;
        _agregarNoticia(
          '¡Bancarrota! Tu agencia no puede seguir funcionando.',
          TipoNoticia.alerta,
        );
      } else {
        _agregarNoticia(
          'Estás en números rojos (semana ${ag.semanasEnNegativo} de $semanasParaBancarrota).',
          TipoNoticia.alerta,
        );
      }
    } else {
      ag.semanasEnNegativo = 0;
    }

    // 11) Recalculo los valores de mercado.
    _recalcularValores();

    // 12) Bajan los temporizadores después de que la semana los haya usado.
    //     La inactividad de los jugadores ya bajó en la pasada del paso 4.
    if (est.semanasInversor > 0) est.semanasInversor--;
    if (est.semanasContactoGrande > 0) est.semanasContactoGrande--;

    // 13) Eventos aleatorios de la semana (salvo si la partida terminó).
    if (!est.finDelJuego) {
      _generarEventosSemana();
    }

    est.ingresosUltimaSemana = ingresos;
    est.gastosUltimaSemana = gastos;

    await _guardarYNotificar();
  }

  /// Avanza varias semanas seguidas (atajo de depuración).
  Future<void> avanzarSemanas(int cantidad) async {
    if (estado == null || _avanzando) return;
    _avanzando = true;
    notifyListeners();
    try {
      for (var i = 0; i < cantidad; i++) {
        if (estado == null || estado!.finDelJuego) break;
        await _avanzarSemanaInterna();
        // Al avanzar varias semanas, los eventos informativos no se muestran:
        // se resuelven solos y quedan como noticia. Las decisiones sí esperan.
        await resolverEventosInformativos();
      }
    } finally {
      _avanzando = false;
      notifyListeners();
    }
  }

  /// Calcula una sola vez los premios individuales de la temporada.
  void _calcularPremiosTemporada() {
    final est = estado!;
    // Si ya se entregaron los premios de esta temporada, no repito.
    if (est.premios.any((p) => p.temporada == est.temporada)) return;

    final puntosTitulos = _puntosTitulosPorJugador();
    final premiosTemporada = <PremioIndividual>[];
    for (final juego in Juego.values) {
      premiosTemporada.addAll(calcularPremios(est, juego, puntosTitulos));
    }
    final agenteDelAnio = calcularAgenteDelAnio(est);
    if (agenteDelAnio != null) premiosTemporada.add(agenteDelAnio);

    est.premios.addAll(premiosTemporada);
    aplicarEfectosPremios(est, premiosTemporada);
    est.ceremoniaPendiente = premiosTemporada.isNotEmpty;
  }

  /// Puntos de títulos por jugador para el puntaje del Jugador del Año.
  Map<String, double> _puntosTitulosPorJugador() {
    final est = estado!;
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

  /// Marca la ceremonia de premios como vista.
  Future<void> ceremoniaVista() async {
    if (estado == null) return;
    estado!.ceremoniaPendiente = false;
    await _guardarYNotificar();
  }

  /// Simula lo que toca jugar en la semana actual en todas las ligas.
  void _simularEtapaActual() {
    final est = estado!;

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
        simularFecha(comp, split, fecha, _indiceEquipos, est.jugadores, _rnd);
        final nuevos = comp.resultadosDeSplit(split).sublist(antes);
        _noticiasDeResultados(nuevos);
        _noticiasDeRachas(comp);
      } else if (splitPlayoff != null) {
        final antes = comp.resultadosPlayoffsDe(splitPlayoff).length;
        jugarPlayoffs(comp, splitPlayoff, _indiceEquipos, est.jugadores, _rnd);
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
    final est = estado!;
    for (final juego in Juego.values) {
      var torneo = torneoDe(juego, TipoTorneo.mitad);
      if (torneo == null) {
        torneo = crearTorneoMitad(est, juego, _indiceEquipos);
        est.torneos.add(torneo);
      }
      final campeonAntes = torneo.campeonId;
      avanzarTorneoMitad(
        torneo,
        equipos: _indiceEquipos,
        jugadores: est.jugadores,
        rnd: _rnd,
        semana: est.semana,
      );
      if (campeonAntes == null && torneo.campeonId != null) {
        _cerrarTorneo(torneo);
      }
    }
  }

  /// Crea y avanza el Mundial (o Major) de cada videojuego.
  void _simularMundial() {
    final est = estado!;
    for (final juego in Juego.values) {
      var torneo = torneoDe(juego, TipoTorneo.mundial);
      if (torneo == null) {
        torneo = crearTorneoMundial(est, juego, _indiceEquipos);
        est.torneos.add(torneo);
      }
      final campeonAntes = torneo.campeonId;
      avanzarTorneoMundial(
        torneo,
        equipos: _indiceEquipos,
        jugadores: est.jugadores,
        rnd: _rnd,
        semana: est.semana,
      );
      if (campeonAntes == null && torneo.campeonId != null) {
        _cerrarTorneo(torneo);
      }
    }
  }

  /// Cierra un torneo: registra el título, reparte premios y aplica efectos.
  void _cerrarTorneo(Torneo torneo) {
    final est = estado!;
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

    repartirPremios(torneo, _indiceEquipos);

    final nombre = _indiceEquipos[campeonId]?.nombre ?? campeonId;
    _agregarNoticia(
      '$nombre es campeón del ${torneo.nombre} de ${torneo.juego.corto}.',
      TipoNoticia.venta,
    );

    final premiados = aplicarEfectosCampeon(torneo, est.jugadores, est.agente);
    if (premiados.isNotEmpty) {
      _agregarNoticia(
        '¡${premiados.map((j) => j.nick).join(', ')} '
        '${premiados.length > 1 ? 'ganaron' : 'ganó'} el ${torneo.nombre}! '
        'Suben su moral, su valor y tu reputación.',
        TipoNoticia.venta,
      );
    }
  }

  /// ¿Tengo algún representado en este equipo?
  bool _tengoRepresentadoEn(String equipoId) => estado!.jugadores.any(
    (j) => j.representadoPorMi && j.equipoId == equipoId,
  );

  /// Noticias de los resultados donde juega algún representado mío.
  void _noticiasDeResultados(List<ResultadoSerie> resultados) {
    for (final r in resultados) {
      if (!_tengoRepresentadoEn(r.localId) &&
          !_tengoRepresentadoEn(r.visitanteId)) {
        continue;
      }
      final local = _indiceEquipos[r.localId];
      final visitante = _indiceEquipos[r.visitanteId];
      if (local == null || visitante == null) continue;
      _agregarNoticia(
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
        final equipo = _indiceEquipos[equipoId];
        if (equipo != null) {
          _agregarNoticia(
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
    final equipo = _indiceEquipos[campeonId];
    final nombre = equipo?.nombre ?? campeonId;
    final texto = '$nombre es campeón de ${comp.liga} (Split $split).';
    if (!estado!.campeonesTemporada.contains(texto)) {
      estado!.campeonesTemporada.add(texto);
      _agregarNoticia(texto, TipoNoticia.venta);
      estado!.palmares.add(
        RegistroCampeon(
          temporada: estado!.temporada,
          juego: comp.juego,
          descripcion: '${comp.liga} (Split $split)',
          tipo: TipoCampeon.liga,
          ganadorId: campeonId,
        ),
      );
    }
  }

  /// Ajusta el valor de mercado según la nota promedio (cada 4 semanas).
  void _ajustarValoresPorNota() {
    for (final j in estado!.jugadores) {
      if (j.partidasTemporada == 0) continue;
      final promedio = j.promedioNota;
      if (promedio >= 7.5) {
        j.multiplicadorValor = (j.multiplicadorValor * 1.05).clamp(
          multiplicadorValorMinimo,
          multiplicadorValorMaximo,
        );
      } else if (promedio <= 4.5) {
        j.multiplicadorValor = (j.multiplicadorValor * 0.95).clamp(
          multiplicadorValorMinimo,
          multiplicadorValorMaximo,
        );
      }
    }
  }

  /// Aplica el progreso semanal de un jugador (mejora o empeora).
  ///
  /// La tabla de probabilidades vive en `progresion.dart` para poder probarla
  /// y ajustarla sin tocar el resto del motor.
  void _progresarJugador(Jugador j) {
    aplicarProgresoSemanal(j, _rnd);
  }

  /// Cambio de temporada: envejecer, retiros, nuevos jóvenes y presupuestos.
  void _nuevaTemporada() {
    final est = estado!;

    // Ascensos y descensos al cerrar la temporada (antes de reiniciar).
    final noticiasAscenso = procesarAscensosYDescensos(est);

    est.semana = 1;
    est.temporada++;
    _agregarNoticia(
      '¡Comienza la temporada ${est.temporada}!',
      TipoNoticia.evento,
    );
    for (final noticia in noticiasAscenso) {
      _agregarNoticia(noticia, TipoNoticia.evento);
    }

    // Envejecen todos; los de 33 o más pueden retirarse.
    final retirados = <Jugador>[];
    for (final j in est.jugadores) {
      j.edad++;
      if (j.edad >= 33 && _rnd.nextDouble() < 0.30) {
        retirados.add(j);
      }
    }
    for (final j in retirados) {
      final equipoId = j.equipoId;
      final rol = j.rol;
      final eraTitular = !j.suplente;
      j.representadoPorMi = false;
      est.jugadores.remove(j);
      _agregarNoticia(
        '${j.nick} se retira a los ${j.edad} años.',
        TipoNoticia.alerta,
      );
      if (equipoId != null && eraTitular) {
        _reponerTitular(equipoId, rol);
      }
    }

    // Defender un título desgasta: los campeones de la temporada anterior
    // empiezan la nueva con menos moral. Ayuda a que un equipo no gane su
    // liga todas las temporadas seguidas.
    _aplicarDesgasteACampeones(est);

    // Se generan 3 jóvenes por región de cada videojuego (potencial 60–95).
    final nicksUsados = est.jugadores.map((j) => j.nick).toSet();
    for (final juego in Juego.values) {
      for (final region in regionesDeJuego(juego)) {
        for (var i = 0; i < 3; i++) {
          est.jugadores.add(
            generarJovenDeRegion(
              _rnd,
              id: _nuevoId(),
              juego: juego,
              region: region,
              nicksUsados: nicksUsados,
            ),
          );
        }
      }
    }

    // Se recargan los presupuestos de los equipos.
    for (final equipo in est.equipos) {
      equipo.presupuesto = equipo.prestigio * 20000;
    }

    // Los equipos de 2ª División pueden fichar un joven libre de su región.
    _ficharJovenesDeSegunda();

    // Se desbloquean las negociaciones y se limpian ofertas y ventanas.
    est.paresBloqueados.clear();
    est.rondasNegociacion.clear();
    est.ofertas.clear();
    est.fichajesVentana.clear();

    // Se reconstruyen las competiciones (cambian las divisiones por los
    // ascensos y descensos) y se reinician las estadísticas de temporada.
    est.competiciones = _crearCompeticiones(est.equipos);
    est.torneos = [];
    est.ceremoniaPendiente = false;
    for (final j in est.jugadores) {
      // La pretemporada cura lesiones y descansos.
      j.semanasInactivo = 0;
      j.partidasTemporada = 0;
      j.victoriasTemporada = 0;
      j.notaTotalTemporada = 0;
      j.eliminacionesTemporada = 0;
      j.muertesTemporada = 0;
      j.asistenciasTemporada = 0;
      j.mvpsTemporada = 0;
      j.ultimasNotas.clear();
    }
    est.campeonesTemporada.clear();

    // Limpia lo que crece sin control con las temporadas (A3): noticias
    // viejas, ofertas vencidas y agentes libres sobrantes.
    limpiarDatosAntiguos(est);

    // Los jóvenes y reemplazos nuevos entran en los índices por id.
    _reconstruirIndices();
  }

  /// Resta moral a los jugadores de los equipos que ganaron un título de liga
  /// en la temporada que acaba de terminar.
  ///
  /// Es un desgaste pequeño (10 puntos) y se aplica una sola vez al inicio de
  /// la temporada. No toca a los agentes libres ni a los recién llegados.
  void _aplicarDesgasteACampeones(EstadoPartida est) {
    final temporadaAnterior = est.temporada - 1;
    final desde = est.temporada - 5;
    final titulosRecientes = <String, int>{};
    for (final r in est.palmares) {
      if (r.tipo != TipoCampeon.liga) continue;
      if (r.temporada < desde || r.temporada >= est.temporada) continue;
      titulosRecientes[r.ganadorId] = (titulosRecientes[r.ganadorId] ?? 0) + 1;
    }
    final campeones = <String>{
      ...est.palmares
          .where(
            (r) =>
                r.temporada == temporadaAnterior && r.tipo == TipoCampeon.liga,
          )
          .map((r) => r.ganadorId),
      // Una dinastía con 3 o más títulos recientes también arrastra desgaste.
      ...titulosRecientes.entries.where((e) => e.value >= 3).map((e) => e.key),
    };
    // Desgaste competitivo: cada título reciente por encima de 2 resta un 4 %
    // al poder del equipo, con un tope del 20 %. Se recalcula cada temporada,
    // así que un equipo que deja de ganar recupera su nivel.
    for (final equipo in est.equipos) {
      final titulos = titulosRecientes[equipo.id] ?? 0;
      final descuento = titulos <= 2 ? 0.0 : min(0.20, (titulos - 2) * 0.04);
      equipo.factorPoder = 1.0 - descuento;
    }

    if (campeones.isEmpty) return;

    for (final j in est.jugadores) {
      final equipoId = j.equipoId;
      if (equipoId == null || !campeones.contains(equipoId)) continue;
      j.moral = (j.moral - desgasteMoralCampeon).clamp(0, 100);
    }
  }

  /// Al empezar la temporada, algunos equipos de 2ª División fichan a un
  /// joven libre de su región (como suplente, sin romper la plantilla).
  /// La lógica vive en `mercado.dart` para poder probarla con casos C3.
  void _ficharJovenesDeSegunda() {
    ficharJovenesDeSegunda(estado: estado!, rnd: _rnd);
  }

  /// Recalcula el valor de mercado de todos los jugadores.
  void _recalcularValores() {
    for (final j in estado!.jugadores) {
      j.valorMercado = valorMercadoDe(j);
    }
  }

  // ------------------- UTILIDADES INTERNAS -------------------

  /// Aplica la parte del inversor (10 %) a una comisión si está activo.
  int _comisionNeta(int bruta) {
    if (estado == null || estado!.semanasInversor <= 0) return bruta;
    return (bruta * (1 - eventos.porcentajeComisionesInversor)).round();
  }

  /// Agrega una noticia al principio de la lista (la más reciente arriba).
  void _agregarNoticia(String texto, TipoNoticia tipo) {
    estado!.noticias.insert(
      0,
      Noticia(
        semana: estado!.semana,
        temporada: estado!.temporada,
        texto: texto,
        tipo: tipo,
      ),
    );
    if (estado!.noticias.length > 200) {
      estado!.noticias.removeRange(200, estado!.noticias.length);
    }
  }

  /// Guarda la partida y avisa a las pantallas que se actualicen.
  ///
  /// Los guardados se encadenan en una cola para que dos acciones seguidas no
  /// terminen escribiendo fuera de orden (corrección I5). La interfaz se avisa
  /// antes de esperar al disco, así los botones se bloquean sin tirones.
  Future<void> _guardarYNotificar() async {
    notifyListeners();
    final est = estado;
    if (est == null) return;

    final solicitud = Completer<void>();
    _guardadosPendientes.add((estado: est, completer: solicitud));
    if (_procesandoGuardado) return solicitud.future;

    _procesandoGuardado = true;
    try {
      while (_guardadosPendientes.isNotEmpty) {
        final pendiente = _guardadosPendientes.removeAt(0);
        try {
          await guardarPartida(pendiente.estado);
          pendiente.completer.complete();
        } catch (error, pila) {
          // La cola sigue con el siguiente guardado aunque uno falle.
          pendiente.completer.completeError(error, pila);
        }
      }
    } finally {
      _procesandoGuardado = false;
    }
    return solicitud.future;
  }
}
