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
import '../modelos/torneo.dart';
import '../servicios/guardado.dart';
import 'calendario.dart';
import 'eventos.dart' as eventos;
import 'generador_jugadores.dart';
import 'indices_mundo.dart';
import 'servicios/competicion_service.dart';
import 'servicios/eventos_service.dart';
import 'servicios/mercado_service.dart';
import 'servicios/temporada_service.dart';
import 'liga.dart';
import 'mercado.dart';
import 'metricas.dart';
import 'negociacion.dart';

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
    required this.esLocal,
    required this.misJugadores,
  });

  final Competicion competicion;
  final int fecha;
  final String miEquipoId;
  final String rivalId;

  /// true si mi equipo es el local en ese partido. La previa debe abrirse
  /// con el orden real del calendario, no asumir que mi equipo juega en casa
  /// (M17 de la auditoría).
  final bool esLocal;

  final List<Jugador> misJugadores;

  /// Id del equipo local real del partido.
  String get localId => esLocal ? miEquipoId : rivalId;

  /// Id del equipo visitante real del partido.
  String get visitanteId => esLocal ? rivalId : miEquipoId;
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

  /// Número que sube con cada notificación. Las pestañas lo usan para no
  /// rehacer filtros y ordenaciones si nada cambió (corrección I10).
  int _revision = 0;
  int get revision => _revision;

  @override
  void notifyListeners() {
    _revision++;
    super.notifyListeners();
  }

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

  /// Índices para buscar jugadores y equipos por id en O(1), además de la
  /// plantilla y el titular de cada equipo+rol (correcciones I9/I11).
  final IndicesMundo _indices = IndicesMundo();

  /// Acceso a los índices para los servicios extraídos de este archivo.
  IndicesMundo get indices => _indices;

  // Alias interno para el repuesto de titulares.
  Map<String, Equipo> get _indiceEquipos => _indices.equipos;

  // Servicios extraídos del motor (corrección I11). `MotorJuego` sigue siendo
  // la fachada que usan las pantallas; los métodos públicos delegan en ellos.
  late final MercadoService _mercado = MercadoService(this);
  late final CompeticionService _competicion = CompeticionService(this);
  late final EventosService _eventos = EventosService(this);
  late final TemporadaService _temporada = TemporadaService(this);

  MercadoService get mercadoService => _mercado;
  CompeticionService get competicionService => _competicion;
  EventosService get eventosService => _eventos;
  TemporadaService get temporadaService => _temporada;

  /// Generador aleatorio compartido por los servicios.
  Random get rnd => _rnd;

  /// Crea el siguiente id único de jugador.
  String nuevoId() => _nuevoId();

  /// Registra una noticia (la más reciente arriba).
  void agregarNoticia(String texto, TipoNoticia tipo) =>
      _agregarNoticia(texto, tipo);

  /// Guarda la partida y avisa a las pantallas.
  Future<void> guardarYNotificar() => _guardarYNotificar();

  /// Reconstruye los índices derivados del estado.
  void reconstruirIndices() => _reconstruirIndices();

  /// Reconstruye los índices solo si están vacíos (pruebas/estado manual).
  void asegurarIndices() => _asegurarIndices();

  /// Aplica la parte del inversor a una comisión.
  int comisionNeta(int bruta) => _comisionNeta(bruta);

  /// Repone un titular que falta en un equipo.
  void reponerTitular(String equipoId, String rol) =>
      _reponerTitular(equipoId, rol);

  /// Recalcula todos los valores de mercado.
  void recalcularValores() => _temporada.recalcularValores();

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

  /// Dinero ganado en la semana actual, incluyendo traspasos, renovaciones
  /// y eventos además de las comisiones de salario (M4).
  int get ingresosSemanaActual =>
      (estado?.ingresosUltimaSemana ?? 0) +
      (estado?.ingresosSemanaEnCurso ?? 0);

  /// Dinero gastado en la semana actual, incluyendo eventos y fichajes.
  int get gastosSemanaActual =>
      (estado?.gastosUltimaSemana ?? 0) + (estado?.gastosSemanaEnCurso ?? 0);

  /// Registra un ingreso del agente para el resumen semanal.
  void registrarIngreso(int monto) {
    if (monto > 0 && estado != null) {
      estado!.ingresosSemanaEnCurso += monto;
    }
  }

  /// Registra un gasto del agente para el resumen semanal.
  void registrarGasto(int monto) {
    if (monto > 0 && estado != null) {
      estado!.gastosSemanaEnCurso += monto;
    }
  }

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
  Jugador? jugadorPorId(String id) {
    _asegurarIndices();
    return _indices.jugadorPorId(id);
  }

  /// Busca un equipo por su id.
  Equipo? equipoPorId(String id) {
    _asegurarIndices();
    return _indices.equipoPorId(id);
  }

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
    _asegurarIndices();
    // Split según la semana (antes del parón: Split 1; después: Split 2).
    final split = est.semana <= 20 ? 1 : 2;

    final resultado = <PartidoProgramado>[];
    for (final comp in est.competiciones) {
      // Índice de representados por equipo: no recorre los ~2.800 jugadores
      // por cada competición (corrección I10).
      final misEquipos = _indices.representadosPorEquipo.keys
          .where(comp.equipoIds.contains)
          .toSet();
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
        final misJugadores =
            _indices.representadosPorEquipo[miEquipo] ?? const <Jugador>[];
        resultado.add(
          PartidoProgramado(
            competicion: comp,
            fecha: siguiente,
            miEquipoId: miEquipo,
            rivalId: rival,
            esLocal: miEquipo == local,
            misJugadores: misJugadores,
          ),
        );
      }
    }
    return resultado;
  }

  /// Reconstruye los índices si el estado se asignó directamente (pruebas) o
  /// si quedaron vacíos después de cargar.
  void _asegurarIndices() {
    final est = estado;
    if (est == null) return;
    if (_indices.jugadores.isEmpty && est.jugadores.isNotEmpty) {
      _reconstruirIndices();
    } else if (_indices.equipos.isEmpty && est.equipos.isNotEmpty) {
      _reconstruirIndices();
    }
  }

  /// Reconstruye los índices de jugadores, equipos, plantillas y titulares.
  void _reconstruirIndices() {
    final est = estado!;
    // Además corrige nicks repetidos de partidas viejas o de datos iniciales:
    // el primero conserva el nombre y los demás reciben un número.
    asegurarNicksUnicos(est.jugadores);
    _indices.reconstruir(est);
    // Recupera el contador en partidas v3–v6, que no lo guardaban, o si el
    // valor guardado se quedó atrás. Así el próximo id `p####` no repite.
    if (_indices.siguienteIdJugador > est.siguienteIdJugador) {
      est.siguienteIdJugador = _indices.siguienteIdJugador;
    }
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
      competiciones: _competicion.crearCompeticiones(mundo.equipos),
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
    // Las plantillas solo se reparan en partidas anteriores al formato
    // actual: en una partida v9 válida no hace falta gastar RNG ni alterar
    // plantillas que el jugador ya tenía.
    _repararEstadoCargado(
      repararPlantillas: (carga.version ?? versionFormato) < versionFormato,
    );
    _recalcularValores();
    // Al cargar se guarda de nuevo: así una partida vieja se actualiza al
    // formato actual con el contador de ids reconstruido y el estado
    // derivado reparado (I14). El repositorio conserva una copia `.bak` del
    // guardado anterior antes de reemplazarlo.
    await guardarPartida(estado!);
    notifyListeners();
    return ResultadoCarga.ok;
  }

  /// Repara el estado derivado de las partidas antiguas (I14).
  ///
  /// Las versiones 3–5 podían no traer competiciones o torneos, o tener
  /// plantillas incompletas. Aquí se regeneran las ligas que falten, se
  /// reponen los titulares que no existan y se reconstruyen los torneos de
  /// la temporada en curso si ya deberían haberse jugado.
  void _repararEstadoCargado({required bool repararPlantillas}) {
    final est = estado!;

    // 1) Competiciones: la versión vieja podía guardar la lista vacía.
    if (est.competiciones.isEmpty) {
      est.competiciones = _competicion.crearCompeticiones(est.equipos);
    } else {
      final existentes = est.competiciones
          .map((comp) => comp.identificador)
          .toSet();
      for (final esperada in _competicion.crearCompeticiones(est.equipos)) {
        if (!existentes.contains(esperada.identificador)) {
          est.competiciones.add(esperada);
        }
      }
    }

    // 2) Plantillas: cada equipo debe tener un titular en cada rol. Las
    // partidas viejas podían haber perdido jugadores tras una retirada.
    if (repararPlantillas) {
      for (final equipo in est.equipos) {
        for (final rol in equipo.juego.roles) {
          final tieneTitular = est.jugadores.any(
            (j) => j.equipoId == equipo.id && j.rol == rol && !j.suplente,
          );
          if (!tieneTitular) _reponerTitular(equipo.id, rol);
        }
      }
      _reconstruirIndices();
    }

    // 3) Torneos de la temporada actual que la partida vieja no guardaba.
    _competicion.repararTorneosDeTemporada();
    _reconstruirIndices();
  }

  /// Borra la partida guardada.
  Future<void> borrar() async {
    await borrarPartida();
    estado = null;
    _indices.limpiar();
    // No se avisa a las pantallas después de dejar `estado` a null: sus
    // getters necesitan una partida y podían lanzar una excepción (C2).
    // Las pantallas que borran navegan al inicio justo después.
  }

  // ------------------- ACCIONES DEL AGENTE -------------------

  /// Recluta (representa) a un jugador. Cobra el 5 % de su valor.
  Future<ResultadoAccion> reclutar(Jugador jugador) =>
      _mercado.reclutar(jugador);

  /// Deja de representar a un jugador.
  Future<ResultadoAccion> dejarDeRepresentar(Jugador jugador) =>
      _mercado.dejarDeRepresentar(jugador);

  // ------------------- NEGOCIACIÓN -------------------

  /// Calcula el interés de un equipo por un jugador.
  NivelInteres interesDe(Jugador jugador, Equipo equipo) =>
      _mercado.interesDe(jugador, equipo);

  /// Rondas de negociación que quedan entre un jugador y un equipo.
  int rondasRestantes(Jugador jugador, Equipo equipo) =>
      _mercado.rondasRestantes(jugador, equipo);

  /// ¿Está bloqueado el par jugador+equipo hasta la próxima temporada?
  bool bloqueado(Jugador jugador, Equipo equipo) =>
      _mercado.bloqueado(jugador, equipo);

  /// Motivos por los que no se puede ofrecer a un jugador ahora mismo.
  List<String> motivosParaOfrecer(Jugador jugador, {Equipo? equipo}) =>
      _mercado.motivosParaOfrecer(jugador, equipo: equipo);

  /// ¿Se puede ofrecer a este jugador (y equipo, si se indica)?
  bool puedeOfrecer(Jugador jugador, {Equipo? equipo}) =>
      _mercado.puedeOfrecer(jugador, equipo: equipo);

  /// Envía una oferta de un jugador a un equipo.
  Future<ResultadoOferta> ofrecer({
    required Jugador jugador,
    required Equipo equipo,
    required int precioPedido,
  }) => _mercado.ofrecer(
    jugador: jugador,
    equipo: equipo,
    precioPedido: precioPedido,
  );

  /// Acepta una contraoferta del equipo y cierra el trato.
  Future<ResultadoAccion> aceptarContraoferta({
    required Jugador jugador,
    required Equipo equipo,
    required int precio,
  }) => _mercado.aceptarContraoferta(
    jugador: jugador,
    equipo: equipo,
    precio: precio,
  );

  // ------------------- RESPUESTA A OFERTAS -------------------

  /// Acepta una oferta: cierra el traspaso o aplica la renovación.
  Future<ResultadoAccion> aceptarOferta(Oferta oferta) =>
      _mercado.aceptarOferta(oferta);

  /// Rechaza una oferta. Si era de renovación, el jugador quedará libre.
  Future<ResultadoAccion> rechazarOferta(Oferta oferta) =>
      _mercado.rechazarOferta(oferta);

  /// Pide más dinero por una oferta de traspaso.
  Future<ResultadoAccion> pedirMasOferta(Oferta oferta) =>
      _mercado.pedirMasOferta(oferta);

  // ------------------- EVENTOS ALEATORIOS -------------------

  /// Resuelve un evento pendiente con la opción elegida (0 = A, 1 = B).
  Future<ResultadoAccion> resolverEvento(EventoPendiente evento, int opcion) =>
      _eventos.resolverEvento(evento, opcion);

  /// Resuelve automáticamente los eventos informativos (sin decisión).
  Future<void> resolverEventosInformativos() => _eventos.resolverInformativos();

  /// Cambia la frecuencia con la que aparecen los eventos aleatorios.
  Future<void> cambiarFrecuenciaEventos(FrecuenciaEventos frecuencia) =>
      _eventos.cambiarFrecuencia(frecuencia);

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
      _indices.registrar(reemplazo);
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
      await _temporada.avanzarSemanaInterna();
    } finally {
      _avanzando = false;
      notifyListeners();
    }
  }

  /// Avanza varias semanas seguidas (atajo de depuración).
  Future<void> avanzarSemanas(int cantidad) async {
    if (estado == null || _avanzando) return;
    _avanzando = true;
    notifyListeners();
    try {
      for (var i = 0; i < cantidad; i++) {
        if (estado == null || estado!.finDelJuego) break;
        await _temporada.avanzarSemanaInterna();
        // Al avanzar varias semanas, los eventos informativos no se muestran:
        // se resuelven solos y quedan como noticia. Las decisiones sí esperan.
        await _eventos.resolverInformativos();
      }
    } finally {
      _avanzando = false;
      notifyListeners();
    }
  }

  /// Marca la ceremonia de premios como vista.
  Future<void> ceremoniaVista() async {
    if (estado == null) return;
    estado!.ceremoniaPendiente = false;
    await _guardarYNotificar();
  }

  // ------------------- UTILIDADES INTERNAS -------------------

  /// Recalcula los valores de mercado (alias interno de compatibilidad).
  void _recalcularValores() => _temporada.recalcularValores();

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
