// Motor del juego: guarda todo el estado y contiene las acciones
// (reclutar, ofrecer, avanzar semana...). Extiende ChangeNotifier para
// que las pantallas se actualicen solas cuando algo cambia.
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../datos/cargador_mundo.dart';
import '../modelos/agente.dart';
import '../modelos/agente_rival.dart';
import '../modelos/competicion.dart';
import '../modelos/equipo.dart';
import '../modelos/estado_partida.dart';
import '../modelos/evento.dart';
import '../modelos/historial.dart';
import '../modelos/juego.dart';
import '../modelos/jugador.dart';
import '../modelos/noticia.dart';
import '../modelos/oferta.dart';
import '../modelos/ojeador.dart';
import '../modelos/staff.dart';
import '../modelos/torneo.dart';
import '../servicios/guardado.dart';
import 'agentes_rivales.dart' as rivales;
import 'academia.dart' as academia;
import 'calendario.dart';
import 'eventos.dart' as eventos;
import 'formulas.dart';
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
import 'ojeadores.dart' as ojeadores_logica;
import 'satisfaccion.dart' as sat;
import 'staff.dart' as staff_logica;

/// Resultado simple de una acción (reclutar, dejar de representar...).
class ResultadoAccion {
  ResultadoAccion(
    this.ok,
    this.mensaje, {
    this.huboDisputa = false,
    this.ganoRival = false,
    this.rivalNombre,
  });

  final bool ok;
  final String mensaje;

  /// true si al reclamar al jugador apareció un agente rival.
  final bool huboDisputa;

  /// true si la disputa la ganó el rival y el jugador se fue con él.
  final bool ganoRival;

  /// Nombre del rival que participó en la disputa, si hubo.
  final String? rivalNombre;
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

/// Las plantillas completas se garantizan desde la Parte 3A (formato 10).
/// Las partidas v10 ya son válidas: al migrar a v11 no hay que regenerar
/// titulares ni gastar RNG. Solo las v3–v9 necesitan la reparación.
const int versionPlantillasReparadas = 10;

/// El motor principal del juego.
class MotorJuego extends ChangeNotifier {
  /// Crea el motor. Si se indica [semilla], todas las tiradas aleatorias de
  /// la partida son reproducibles. Con `null` se comporta como siempre.
  ///
  /// [random] permite inyectar un generador controlado en las pruebas.
  MotorJuego({int? semilla, Random? random})
    : semilla = semilla,
      _rnd = random ?? Random(semilla);

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

  /// Avisos de robos de rivales que la interfaz muestra una sola vez. Viven
  /// solo en memoria: la noticia roja permanece en el historial, pero el
  /// aviso destacado no necesita guardarse.
  final List<String> _avisosRivales = [];

  /// Copia de los avisos pendientes de mostrar.
  List<String> get avisosRivales => List.unmodifiable(_avisosRivales);

  /// Registra un aviso destacado de un rival (por ejemplo, un robo).
  void registrarAvisoRival(String texto) {
    if (texto.isNotEmpty) _avisosRivales.add(texto);
  }

  /// Vacía los avisos después de que la interfaz los haya mostrado.
  void limpiarAvisosRivales() => _avisosRivales.clear();

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

  /// Agentes rivales de la partida (Parte 3A).
  List<AgenteRival> get agentesRivales => estado?.agentesRivales ?? const [];

  /// Ojeadores contratados por la agencia (Parte 3C).
  List<Ojeador> get ojeadores => estado?.ojeadores ?? const [];

  /// Staff contratado por la agencia (Parte 3D).
  List<MiembroStaff> get staff => estado?.staff ?? const [];

  /// Miembro que ocupa un puesto del staff, o null si está vacante.
  MiembroStaff? miembroStaff(RolStaff rol) =>
      estado == null ? null : staff_logica.miembroDeRol(estado!, rol);

  /// Nivel del staff en un puesto (0 si está vacante).
  int nivelStaff(RolStaff rol) =>
      estado == null ? 0 : staff_logica.nivelDeRol(estado!, rol);

  /// Gasto semanal de todos los miembros del staff.
  int get gastoStaffSemanal => staff_logica.gastoSemanalStaff(staff);

  /// Gasto semanal de la academia (Parte 3E): $150 por cada joven.
  int get gastoAcademiaSemanal =>
      estado == null ? 0 : academia.gastoSemanalAcademia(estado!);

  /// Jóvenes que están entrenando en la academia.
  List<Jugador> get jovenesAcademia =>
      estado == null ? const [] : academia.jovenesEnAcademia(estado!);

  /// Candidatos de la academia que todavía no he reclutado.
  List<Jugador> get candidatosAcademia =>
      estado == null ? const [] : academia.candidatosDeAcademia(estado!);

  /// Plazas libres de la academia.
  int get plazasLibresAcademia => estado == null
      ? academia.capacidadAcademia
      : academia.plazasLibresAcademia(estado!);

  /// Jóvenes que ya pueden colocarse si el mercado está abierto.
  List<Jugador> get jovenesListosParaColocar =>
      estado == null ? const [] : academia.jovenesListosParaColocar(estado!);

  /// true si la ventana actual permite colocar jóvenes.
  bool get ventanaAcademiaAbierta =>
      estado != null && academia.ventanaDeColocacionAbierta(estado!);

  /// Motivos por los que no se puede colocar a un joven ahora mismo.
  List<String> motivosParaColocarJoven(Jugador jugador) => estado == null
      ? const ['No hay partida.']
      : academia.motivosParaColocar(estado!, jugador);

  /// Equipos de 2ª División que pueden pagar al joven.
  List<Equipo> equiposParaColocar(Jugador jugador) =>
      estado == null ? const [] : academia.equiposParaColocar(estado!, jugador);

  /// Gasto fijo semanal total de la agencia: oficina + ojeadores + staff +
  /// academia. Es la línea que se muestra en Mi agencia.
  int get gastoFijoSemanalTotal =>
      gastoOficinaSemanal +
      gastoOjeadoresSemanal +
      gastoStaffSemanal +
      gastoAcademiaSemanal;

  /// Costo de subir un nivel a un miembro del staff.
  int costoMejoraStaff(MiembroStaff miembro) =>
      staff_logica.costoMejoraStaff(miembro);

  /// Margen de aceptación que tengo con un equipo: abogado + contacto grande,
  /// con el tope de +0,10. Si [equipo] es null solo cuenta el abogado.
  double margenAceptacionPara(Equipo? equipo) {
    final contacto =
        equipo != null &&
            equipo.prestigio >= 85 &&
            (estado?.semanasContactoGrande ?? 0) > 0
        ? eventos.margenContactoGrande
        : 0.0;
    return staff_logica.margenAceptacionTotal(
      nivelAbogado: nivelStaff(RolStaff.abogado),
      margenContacto: contacto,
    );
  }

  /// Límite de aceptación visible (1,05 + margen) para un equipo.
  double limiteAceptacionPara(Equipo? equipo) =>
      limiteAceptacion + margenAceptacionPara(equipo);

  /// Cupos de ojeadores que quedan libres.
  int get cuposOjeadores => ojeadores_logica.maxOjeadores - ojeadores.length;

  /// Gasto semanal de todos los ojeadores.
  int get gastoOjeadoresSemanal =>
      ojeadores_logica.gastoSemanalOjeadores(ojeadores);

  /// Talentos ocultos que el jugador puede ver con sus ojeadores actuales.
  List<Jugador> get talentosDescubiertos => estado == null
      ? const []
      : ojeadores_logica.talentosOcultosVisibles(estado!);

  /// true si algún ojeador cubre el videojuego y la región del jugador.
  bool cubiertoPorOjeador(Jugador jugador) {
    if (estado == null) return false;
    _asegurarIndices();
    return ojeadores_logica.nivelOjeadorQueCubre(
          ojeadores: ojeadores,
          jugador: jugador,
          equipos: _indices.equipos,
        ) >
        0;
  }

  /// Nota de precisión del rango de potencial ("Ojeador nivel 3 · 6 semanas"
  /// o "Sin ojeador").
  String notaPrecisionPotencial(Jugador jugador) {
    if (estado == null) return 'Sin ojeador';
    _asegurarIndices();
    return ojeadores_logica.notaPrecisionPotencial(
      jugador: jugador,
      ojeadores: ojeadores,
      equipos: _indices.equipos,
    );
  }

  /// Ranking de agentes conmigo incluido.
  List<rivales.FilaRankingAgente> get rankingAgentes =>
      rivales.rankingAgentes(estado!);

  /// Rival que representa a un jugador, o null si no tiene agente rival.
  AgenteRival? agenteRivalDe(Jugador jugador) =>
      rivales.rivalDeJugador(estado!, jugador);

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

  /// Los jugadores que yo represento de forma normal. Los jóvenes de la
  /// academia viven en su propia pantalla y no cuentan para la cartera.
  List<Jugador> get misJugadores => estado!.jugadores
      .where((j) => j.representadoPorMi && !j.enAcademia)
      .toList();

  /// Mis 3 jugadores más valiosos (para el resumen).
  List<Jugador> get misMejoresJugadores {
    final lista =
        estado!.jugadores
            .where((j) => j.representadoPorMi && !j.enAcademia)
            .toList()
          ..sort((a, b) => b.valorMercado.compareTo(a.valorMercado));
    return lista.take(3).toList();
  }

  // ------------------- SATISFACCIÓN (PARTE 3B) -------------------

  /// Satisfacción media de mis representados (0 si no tengo ninguno).
  double get satisfaccionMedia {
    final jugadores = misJugadores;
    if (jugadores.isEmpty) return 0;
    final suma = jugadores.fold<int>(0, (total, j) => total + j.satisfaccion);
    return suma / jugadores.length;
  }

  /// Representados que quieren hablar conmigo, de menor a mayor satisfacción.
  List<Jugador> get representadosQueQuierenHablar =>
      misJugadores.where((j) => j.quiereHablar).toList()
        ..sort((a, b) => a.satisfaccion.compareTo(b.satisfaccion));

  /// Número de representados que quieren hablar (contador de avisos).
  int get avisosSatisfaccion => representadosQueQuierenHablar.length;

  /// Número de representados en riesgo de marcharse.
  int get representadosEnRiesgo => misJugadores
      .where((j) => j.satisfaccion < sat.satisfaccionCritica)
      .length;

  /// Los representados con menor satisfacción.
  List<Jugador> representadosMasDescontentos([int cantidad = 3]) {
    final lista = misJugadores
      ..sort((a, b) => a.satisfaccion.compareTo(b.satisfaccion));
    return lista.take(cantidad).toList();
  }

  /// Etiqueta visible de una expectativa.
  String etiquetaExpectativa(String clave) => sat.etiquetaExpectativa(clave);

  /// Expectativas actuales de un jugador.
  List<String> expectativasDe(Jugador jugador) =>
      List.unmodifiable(jugador.expectativas);

  /// true si una expectativa del jugador se cumple ahora mismo.
  bool expectativaCumplida(Jugador jugador, String clave) =>
      sat.expectativaCumplida(
        jugador: jugador,
        clave: clave,
        equipo: sat.equipoDe(estado!, jugador),
      );

  /// Comisión máxima que aceptaría el jugador para una duración concreta.
  double comisionMaximaAceptablePara(Jugador jugador, int duracionSemanas) =>
      sat.comisionMaximaAceptable(
        satisfaccion: jugador.satisfaccion,
        duracionSemanas: duracionSemanas,
      );

  /// Costo del bono para apaciguar a un jugador.
  int costoBonoApaciguar(Jugador jugador) => sat.costoBonoApaciguar(jugador);

  /// Promete al jugador que mejorarás su situación (+10 ahora).
  Future<ResultadoAccion> prometerMejora(Jugador jugador) async {
    if (!jugador.representadoPorMi) {
      return ResultadoAccion(false, 'No representas a ${jugador.nick}.');
    }
    if (!jugador.quiereHablar) {
      return ResultadoAccion(
        false,
        '${jugador.nick} no quiere hablar contigo ahora mismo.',
      );
    }
    if (jugador.semanasPromesaPendiente > 0) {
      return ResultadoAccion(
        false,
        'Ya tienes una promesa pendiente con ${jugador.nick}.',
      );
    }
    sat.aplicarSatisfaccion(jugador, sat.promesaSatisfaccion);
    jugador.semanasPromesaPendiente = sat.semanasPromesaPendiente;
    jugador.quiereHablar = false;
    _agregarNoticia(
      'Prometiste a ${jugador.nick} que mejorarás su situación. Tienes '
      '${sat.semanasPromesaPendiente} semanas para cumplirlo.',
      TipoNoticia.evento,
    );
    await _guardarYNotificar();
    return ResultadoAccion(
      true,
      '${jugador.nick} confía en tu promesa. Quedan '
      '${sat.semanasPromesaPendiente} semanas.',
    );
  }

  /// Paga un bono del 5 % del valor para apaciguar al jugador (+15).
  Future<ResultadoAccion> pagarBono(Jugador jugador) async {
    if (!jugador.representadoPorMi) {
      return ResultadoAccion(false, 'No representas a ${jugador.nick}.');
    }
    if (!jugador.quiereHablar) {
      return ResultadoAccion(
        false,
        '${jugador.nick} no quiere hablar contigo ahora mismo.',
      );
    }
    final costo = sat.costoBonoApaciguar(jugador);
    if (agente.dinero < costo) {
      return ResultadoAccion(
        false,
        'No tienes dinero suficiente para el bono '
        '(${formatearDinero(costo)}).',
      );
    }
    agente.dinero -= costo;
    registrarGasto(costo);
    sat.aplicarSatisfaccion(jugador, sat.bonoSatisfaccion);
    jugador.quiereHablar = false;
    _agregarNoticia(
      'Pagaste un bono de ${formatearDinero(costo)} a ${jugador.nick}.',
      TipoNoticia.evento,
    );
    await _guardarYNotificar();
    return ResultadoAccion(
      true,
      'Le pagaste ${formatearDinero(costo)} a ${jugador.nick}.',
    );
  }

  /// Ignora al jugador que quiere hablar (−10 de satisfacción).
  Future<ResultadoAccion> ignorarJugador(Jugador jugador) async {
    if (!jugador.representadoPorMi) {
      return ResultadoAccion(false, 'No representas a ${jugador.nick}.');
    }
    sat.aplicarSatisfaccion(jugador, -sat.castigoIgnorarJugador);
    jugador.quiereHablar = false;
    _agregarNoticia(
      'Ignoraste a ${jugador.nick}, que quería hablar contigo.',
      TipoNoticia.alerta,
    );
    await _guardarYNotificar();
    return ResultadoAccion(true, 'Ignoraste a ${jugador.nick}.');
  }

  /// Renueva el contrato de representación si el jugador lo acepta.
  Future<ResultadoAccion> renegociarContratoRepresentacion(
    Jugador jugador, {
    required double comision,
    required int duracionSemanas,
  }) async {
    if (!jugador.representadoPorMi) {
      return ResultadoAccion(false, 'No representas a ${jugador.nick}.');
    }
    if (jugador.semanasContratoRepresentacion >
        sat.umbralSemanasRenovacionRepresentacion) {
      return ResultadoAccion(
        false,
        'Todavía quedan ${jugador.semanasContratoRepresentacion} semanas de '
        'contrato. Podrás renegociar cuando queden '
        '${sat.umbralSemanasRenovacionRepresentacion} o menos.',
      );
    }
    if (!sat.aceptaRenovacionRepresentacion(
      satisfaccion: jugador.satisfaccion,
      comisionOfrecida: comision,
      duracionSemanas: duracionSemanas,
    )) {
      final maxima = sat.comisionMaximaAceptable(
        satisfaccion: jugador.satisfaccion,
        duracionSemanas: duracionSemanas,
      );
      return ResultadoAccion(
        false,
        '${jugador.nick} no acepta esa oferta. Para '
        '$duracionSemanas semanas aceptaría como máximo '
        '${sat.formatearComision(maxima)}.',
      );
    }
    jugador.comisionSalarioContrato = comision;
    jugador.semanasContratoRepresentacion = duracionSemanas;
    _agregarNoticia(
      'Renegociaste el contrato de representación de ${jugador.nick}: '
      '${sat.formatearComision(comision)} durante $duracionSemanas semanas.',
      TipoNoticia.fichaje,
    );
    await _guardarYNotificar();
    return ResultadoAccion(
      true,
      'Contrato renovado con ${jugador.nick}: '
      '${sat.formatearComision(comision)} durante $duracionSemanas semanas.',
    );
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
    // La competencia empieza desde el primer día (Parte 3A).
    rivales.asegurarAgentesRivales(estado!, _rnd);
    // Todos los jugadores del mundo ya nacieron con su potencial oculto en
    // los generadores; esta llamada idempotente cubre datos cargados a mano.
    ojeadores_logica.inicializarPotencialPartidaNueva(estado!, _rnd);
    // La primera temporada también tiene talentos ocultos que descubrir.
    ojeadores_logica.generarTalentosOcultos(estado!, _rnd);
    // La academia empieza con sus 8 candidatos de la temporada 1.
    academia.generarCandidatosAcademia(estado!, _rnd, _nuevoId);
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
    // El staff se normaliza en todas las versiones: nivel 1–5 y un solo
    // miembro por puesto. Una v12 no trae la lista y queda vacía sin gastar
    // RNG (Parte 3D).
    staff_logica.normalizarStaff(estado!);
    // La academia se normaliza sin gastar RNG. Una partida v13 no genera
    // candidatos aquí: los recibirá al empezar la próxima temporada.
    academia.normalizarAcademia(estado!);
    _reconstruirIndices();
    // Las plantillas solo se reparan en partidas anteriores al formato
    // actual: en una partida v9 válida no hace falta gastar RNG ni alterar
    // plantillas que el jugador ya tenía.
    _repararEstadoCargado(
      repararPlantillas:
          (carga.version ?? versionFormato) < versionPlantillasReparadas,
    );
    _recalcularValores();
    // Partidas v3–v9 no tienen rivales: se generan ahora. En una v10 solo se
    // sincronizan los `agenteId` (sin gastar RNG) para no alterar partidas
    // actuales ni las pruebas que construyen estados controlados.
    final versionCargada = carga.version ?? 0;
    if (versionCargada < versionFormato) {
      rivales.asegurarAgentesRivales(estado!, _rnd);
    } else {
      rivales.normalizarRepresentaciones(estado!);
    }
    // Partidas v3–v10 no traen expectativas ni contrato de representación:
    // se generan aquí sin gastar RNG. En una v11 solo repara datos corruptos.
    sat.asegurarRepresentados(estado!);
    // Partidas anteriores a v12: error de potencial determinista por id, sin
    // gastar RNG, y rango visible nulo para conservar el potencial exacto que
    // el jugador ya conocía. Las v12 solo se normalizan.
    if (versionCargada < 12) {
      ojeadores_logica.migrarPotencialOculto(estado!);
    } else {
      ojeadores_logica.normalizarPotenciales(estado!);
    }
    _reconstruirIndices();
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

  /// Probabilidad de convencer a un jugador de un rival (null si no aplica).
  double? probabilidadConvencer(Jugador jugador) =>
      _mercado.probabilidadConvencer(jugador);

  /// Intenta convencer a un jugador que representa un rival.
  Future<ResultadoAccion> convencer(Jugador jugador) =>
      _mercado.convencer(jugador);

  /// Deja de representar a un jugador.
  Future<ResultadoAccion> dejarDeRepresentar(Jugador jugador) =>
      _mercado.dejarDeRepresentar(jugador);

  // ------------------- OJEADORES (PARTE 3C) -------------------

  /// Contrata un ojeador para un videojuego, una región y un nivel.
  ///
  /// No hay cuota de contratación: solo se pide confirmación en la pantalla.
  /// El salario semanal se cobra en `avanzarSemana`, igual que la oficina.
  Future<ResultadoAccion> contratarOjeador({
    required Juego juego,
    required String region,
    required int nivel,
  }) async {
    final est = estado!;
    if (est.ojeadores.length >= ojeadores_logica.maxOjeadores) {
      return ResultadoAccion(
        false,
        'Ya tienes el máximo de ${ojeadores_logica.maxOjeadores} ojeadores.',
      );
    }
    if (!regionesDeJuego(juego).contains(region)) {
      return ResultadoAccion(
        false,
        'La región «$region» no existe en ${juego.nombre}.',
      );
    }
    final ojeador = ojeadores_logica.crearOjeador(
      estado: est,
      rnd: _rnd,
      juego: juego,
      region: region,
      nivel: nivel,
    );
    est.ojeadores.add(ojeador);
    _agregarNoticia(
      'Contrataste a ${ojeador.nombre} como ojeador de '
      '${juego.corto} en $region (nivel ${ojeador.nivel}).',
      TipoNoticia.fichaje,
    );
    await _guardarYNotificar();
    return ResultadoAccion(
      true,
      '${ojeador.nombre} se une a la agencia como ojeador.',
    );
  }

  /// Despide a un ojeador. Deja de cobrar su salario desde la próxima semana.
  Future<ResultadoAccion> despedirOjeador(Ojeador ojeador) async {
    final est = estado!;
    if (!est.ojeadores.contains(ojeador)) {
      return ResultadoAccion(false, 'Ese ojeador ya no trabaja en la agencia.');
    }
    est.ojeadores.remove(ojeador);
    _agregarNoticia(
      'Despediste a ${ojeador.nombre}, ojeador de '
      '${ojeador.juego.corto} en ${ojeador.region}.',
      TipoNoticia.evento,
    );
    await _guardarYNotificar();
    return ResultadoAccion(true, '${ojeador.nombre} ya no trabaja contigo.');
  }

  // ------------------- STAFF (PARTE 3D) -------------------

  /// Contrata al primer miembro de un puesto. Siempre entra en nivel 1 y no
  /// tiene cuota de contratación: solo se paga su salario cada semana.
  Future<ResultadoAccion> contratarStaff(RolStaff rol) async {
    final est = estado!;
    if (est.staff.any((m) => m.rol == rol)) {
      return ResultadoAccion(
        false,
        'Ya tienes ${rol.etiqueta.toLowerCase()} contratado.',
      );
    }
    final miembro = staff_logica.crearMiembroStaff(estado: est, rol: rol);
    est.staff.add(miembro);
    _agregarNoticia(
      'Contrataste a ${miembro.nombre} como '
      '${rol.etiqueta.toLowerCase()} (nivel 1).',
      TipoNoticia.fichaje,
    );
    await _guardarYNotificar();
    return ResultadoAccion(
      true,
      '${miembro.nombre} se une a la agencia como '
      '${rol.etiqueta.toLowerCase()}.',
    );
  }

  /// Sube un nivel a un miembro del staff. Paga la diferencia de salario de
  /// [staff_logica.semanasCostoMejoraStaff] semanas.
  Future<ResultadoAccion> mejorarStaff(MiembroStaff miembro) async {
    final est = estado!;
    if (!est.staff.contains(miembro)) {
      return ResultadoAccion(false, 'Ese miembro ya no trabaja en la agencia.');
    }
    if (miembro.nivel >= 5) {
      return ResultadoAccion(
        false,
        '${miembro.nombre} ya está en el nivel máximo.',
      );
    }
    final costo = staff_logica.costoMejoraStaff(miembro);
    if (agente.dinero < costo) {
      return ResultadoAccion(
        false,
        'No tienes dinero suficiente para la mejora '
        '(${formatearDinero(costo)}).',
      );
    }
    agente.dinero -= costo;
    registrarGasto(costo);
    miembro.nivel++;
    _agregarNoticia(
      'Mejoraste a ${miembro.nombre} a nivel ${miembro.nivel}.',
      TipoNoticia.fichaje,
    );
    await _guardarYNotificar();
    return ResultadoAccion(
      true,
      '${miembro.nombre} sube a nivel ${miembro.nivel}.',
    );
  }

  /// Despide a un miembro del staff. Es gratis y deja de cobrar desde la
  /// próxima semana.
  Future<ResultadoAccion> despedirStaff(MiembroStaff miembro) async {
    final est = estado!;
    if (!est.staff.remove(miembro)) {
      return ResultadoAccion(false, 'Ese miembro ya no trabaja en la agencia.');
    }
    _agregarNoticia(
      'Despediste a ${miembro.nombre}, '
      '${miembro.rol.etiqueta.toLowerCase()} de la agencia.',
      TipoNoticia.evento,
    );
    await _guardarYNotificar();
    return ResultadoAccion(true, '${miembro.nombre} ya no trabaja contigo.');
  }

  // ------------------- ACADEMIA (PARTE 3E) -------------------

  /// Recluta a un candidato para la academia. Cuesta $500 y ocupa una plaza.
  Future<ResultadoAccion> reclutarJovenAcademia(Jugador jugador) async {
    final est = estado!;
    if (!jugador.candidatoAcademia || jugador.enAcademia) {
      return ResultadoAccion(
        false,
        '${jugador.nick} no es un candidato libre.',
      );
    }
    if (academia.jovenesEnAcademia(est).length >=
        academia.capacidadAcademia) {
      return ResultadoAccion(
        false,
        'La academia está llena (${academia.capacidadAcademia} plazas).',
      );
    }
    if (agente.dinero < academia.costoFichajeAcademia) {
      return ResultadoAccion(
        false,
        'No tienes dinero suficiente (necesitas '
        '${formatearDinero(academia.costoFichajeAcademia)}).',
      );
    }

    agente.dinero -= academia.costoFichajeAcademia;
    registrarGasto(academia.costoFichajeAcademia);
    jugador.candidatoAcademia = false;
    jugador.enAcademia = true;
    jugador.semanasEnAcademia = 0;
    jugador.representadoPorMi = true;
    jugador.agenteId = 'yo';
    jugador.semanasRepresentado = 0;
    jugador.satisfaccion = 70;
    jugador.expectativas = [];
    jugador.quiereHablar = false;
    jugador.semanasPromesaPendiente = 0;
    jugador.semanasContratoRepresentacion = 52;
    jugador.comisionSalarioContrato = 0.05;
    jugador.semanasEnfriamientoAgente = 0;
    jugador.semanasEsperaConvencer = 0;
    _indices.actualizar(jugador);
    _agregarNoticia(
      'Fichaste a ${jugador.nick} para tu academia por '
      '${formatearDinero(academia.costoFichajeAcademia)}.',
      TipoNoticia.fichaje,
    );
    await _guardarYNotificar();
    return ResultadoAccion(true, '${jugador.nick} se une a la academia.');
  }

  /// Coloca a un joven de la academia en un equipo de 2ª División.
  ///
  /// El equipo paga el valor de mercado completo y la agencia recibe los
  /// derechos de formación. No hay club vendedor ni comisión de traspaso.
  Future<ResultadoAccion> colocarJovenAcademia(
    Jugador jugador,
    Equipo equipo,
  ) async {
    final est = estado!;
    final motivos = academia.motivosParaColocar(est, jugador);
    if (motivos.isNotEmpty) return ResultadoAccion(false, motivos.first);
    if (!academia
        .equiposParaColocar(est, jugador)
        .any((e) => e.id == equipo.id)) {
      return ResultadoAccion(
        false,
        '${equipo.nombre} no puede pagar el valor de mercado de ${jugador.nick}.',
      );
    }

    final valor = jugador.valorMercado;
    final derechos = (valor * academia.porcentajeDerechosFormacion).round();
    equipo.presupuesto -= valor;
    agente.dinero += derechos;
    registrarIngreso(derechos);

    // Si el rol ya estaba ocupado, el titular baja a suplente. Si sobran
    // suplentes, el más débil queda libre, como en cualquier traspaso.
    for (final otro in est.jugadores) {
      if (otro.id != jugador.id &&
          otro.equipoId == equipo.id &&
          otro.rol == jugador.rol &&
          !otro.suplente) {
        otro.suplente = true;
        _indices.actualizar(otro);
      }
    }
    for (final sobrante in recortarSuplentes(est, equipo)) {
      _indices.actualizar(sobrante);
      _agregarNoticia(
        '${sobrante.nick} quedó libre para hacer sitio en ${equipo.nombre}.',
        TipoNoticia.evento,
      );
    }

    jugador.enAcademia = false;
    jugador.candidatoAcademia = false;
    jugador.semanasEnAcademia = 0;
    jugador.equipoId = equipo.id;
    jugador.suplente = false;
    jugador.semanasComoSuplente = 0;
    jugador.semanasContrato = 52;
    jugador.semanasContratoRepresentacion = 52;
    jugador.comisionSalarioContrato = 0.05;
    jugador.representadoPorMi = true;
    jugador.agenteId = 'yo';
    jugador.semanasRepresentado = 0;
    jugador.satisfaccion = 70;
    jugador.quiereHablar = false;
    jugador.semanasPromesaPendiente = 0;
    jugador.temporadaUltimoTraspaso = est.temporada;
    jugador.salarioAnual = calcularSalarioAnual(valor);
    jugador.expectativas = sat.generarExpectativas(
      jugador: jugador,
      equipo: equipo,
    );
    _indices.actualizar(jugador);
    _mercado.invalidarOfertasObsoletas();
    _agregarNoticia(
      'Colocaste a ${jugador.nick} en ${equipo.nombre}. Derechos de '
      'formación: ${formatearDinero(derechos)}.',
      TipoNoticia.venta,
    );
    await _guardarYNotificar();
    return ResultadoAccion(
      true,
      '${jugador.nick} ficha por ${equipo.nombre}. Cobras '
      '${formatearDinero(derechos)} en derechos de formación.',
    );
  }

  /// Deja libre a un joven que sigue en la academia.
  Future<ResultadoAccion> soltarJovenAcademia(Jugador jugador) async {
    if (!jugador.enAcademia) {
      return ResultadoAccion(false, '${jugador.nick} no está en la academia.');
    }
    academia.liberarJovenDeAcademia(jugador);
    _indices.actualizar(jugador);
    _agregarNoticia(
      '${jugador.nick} deja la academia y queda como agente libre.',
      TipoNoticia.evento,
    );
    await _guardarYNotificar();
    return ResultadoAccion(true, '${jugador.nick} queda libre.');
  }

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
