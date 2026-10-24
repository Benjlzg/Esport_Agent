// Estado completo de una partida. Es todo lo que se guarda y se carga.
import 'agente.dart';
import 'agente_rival.dart';
import 'competicion.dart';
import 'equipo.dart';
import 'evento.dart';
import 'historial.dart';
import 'jugador.dart';
import 'noticia.dart';
import 'oferta.dart';
import 'ojeador.dart';
import 'staff.dart';
import 'torneo.dart';

/// Versión del formato de guardado. Si algún día cambia el formato,
/// se sube este número para poder actualizar partidas antiguas.
const int versionFormato = 13;

/// Versión más antigua que todavía se puede cargar. Las partidas de las
/// versiones 3 a 12 se actualizan a la 13: los campos nuevos quedan vacíos o
/// con su valor por defecto, el contador de ids se reconstruye al cargar,
/// se generan los agentes rivales, las expectativas de mis representados, se
/// asigna el error de potencial a las partidas antiguas, el staff queda vacío
/// y las competiciones/plantillas que falten se reparan. Las de la versión 1
/// o 2 siguen siendo incompatibles.
const int versionMinimaCompatible = 3;

/// Contiene todos los datos de la partida en curso.
class EstadoPartida {
  EstadoPartida({
    required this.agente,
    required this.jugadores,
    required this.equipos,
    required this.noticias,
    List<Competicion>? competiciones,
    List<String>? campeonesTemporada,
    List<Torneo>? torneos,
    List<RegistroCampeon>? palmares,
    List<PremioIndividual>? premios,
    List<Oferta>? ofertas,
    List<AgenteRival>? agentesRivales,
    List<Ojeador>? ojeadores,
    List<MiembroStaff>? staff,
    Map<String, int>? fichajesVentana,
    List<EventoPendiente>? eventosPendientes,
    Map<String, int>? ultimaSemanaEvento,
    this.frecuenciaEventos = 'normal',
    this.semanasInversor = 0,
    this.semanasContactoGrande = 0,
    this.ceremoniaPendiente = false,
    this.semana = 1,
    this.temporada = 1,
    this.siguienteIdJugador = 0,
    Map<String, int>? rondasNegociacion,
    List<String>? paresBloqueados,
    this.ingresosUltimaSemana = 0,
    this.gastosUltimaSemana = 0,
    this.ingresosSemanaEnCurso = 0,
    this.gastosSemanaEnCurso = 0,
    this.finDelJuego = false,
  }) : competiciones = competiciones ?? [],
       campeonesTemporada = campeonesTemporada ?? [],
       torneos = torneos ?? [],
       palmares = palmares ?? [],
       premios = premios ?? [],
       ofertas = ofertas ?? [],
       agentesRivales = agentesRivales ?? [],
       ojeadores = ojeadores ?? [],
       staff = staff ?? [],
       fichajesVentana = fichajesVentana ?? {},
       eventosPendientes = eventosPendientes ?? [],
       ultimaSemanaEvento = ultimaSemanaEvento ?? {},
       rondasNegociacion = rondasNegociacion ?? {},
       paresBloqueados = paresBloqueados ?? [];

  /// El agente (tú).
  Agente agente;

  /// Todos los jugadores del mundo del juego.
  List<Jugador> jugadores;

  /// Todos los equipos.
  List<Equipo> equipos;

  /// Historial de noticias.
  List<Noticia> noticias;

  /// Ligas del mundo: una por videojuego + región + división.
  List<Competicion> competiciones;

  /// Campeones de la temporada en curso (texto para las noticias).
  List<String> campeonesTemporada;

  /// Torneos internacionales jugados (mitad de temporada y Mundiales).
  List<Torneo> torneos;

  /// Palmarés histórico: todos los títulos ganados por temporada.
  List<RegistroCampeon> palmares;

  /// Premios individuales entregados en las ceremonias.
  List<PremioIndividual> premios;

  /// Ofertas pendientes de respuesta (traspasos y renovaciones).
  List<Oferta> ofertas;

  /// Agentes rivales que compiten conmigo (Parte 3A).
  List<AgenteRival> agentesRivales;

  /// Ojeadores contratados por la agencia (Parte 3C).
  List<Ojeador> ojeadores;

  /// Staff contratado por la agencia (Parte 3D): abogado, relaciones públicas
  /// y preparador. Máximo un miembro por puesto.
  List<MiembroStaff> staff;

  /// Fichajes de la IA hechos por cada equipo en la ventana en curso.
  /// La clave es el id del equipo. Se reinicia al empezar cada ventana.
  Map<String, int> fichajesVentana;

  /// Eventos generados que todavía no se han resuelto (Parte 2E).
  List<EventoPendiente> eventosPendientes;

  /// Última semana absoluta en que salió cada evento. La clave la construye
  /// `claveEsperaEvento` (corrección 2.5 B2). En partidas viejas está vacío.
  Map<String, int> ultimaSemanaEvento;

  /// Frecuencia de eventos elegida en Ajustes: "baja", "normal" o "alta".
  String frecuenciaEventos;

  /// Semanas que quedan con un inversor activo (10 % de comisiones).
  int semanasInversor;

  /// Semanas que quedan con el contacto en un equipo grande activo.
  int semanasContactoGrande;

  /// true cuando hay una ceremonia de premios pendiente de mostrar.
  bool ceremoniaPendiente;

  /// Semana actual, de 1 a 52.
  int semana;

  /// Temporada actual. Empieza en 1.
  int temporada;

  /// Siguiente número que se usará para generar un id `p####` de jugador.
  /// Se guarda para que, al cargar una partida, los jugadores nuevos no
  /// repitan ids ya existentes (corrección C1 de la auditoría).
  int siguienteIdJugador;

  /// Cuántas rondas de negociación se han usado por cada par
  /// jugador+equipo. La clave es "jugadorId|equipoId".
  Map<String, int> rondasNegociacion;

  /// Pares jugador+equipo que no quieren negociar hasta la próxima
  /// temporada. Guarda las mismas claves que rondasNegociacion.
  List<String> paresBloqueados;

  /// Cuánto dinero se ingresó la última semana (para el resumen).
  int ingresosUltimaSemana;

  /// Cuánto dinero se gastó la última semana (para el resumen).
  int gastosUltimaSemana;

  /// Movimientos (traspasos, renovaciones y eventos) ocurridos desde el
  /// último avance de semana. Se suman a los de arriba para que el resumen
  /// muestre todo lo ganado/gastado, no solo las comisiones de salario y la
  /// oficina (M4 de la auditoría).
  int ingresosSemanaEnCurso;
  int gastosSemanaEnCurso;

  /// true cuando el juego terminó por bancarrota.
  bool finDelJuego;

  /// Crea la clave que identifica un par jugador+equipo.
  static String clavePar(String jugadorId, String equipoId) =>
      '$jugadorId|$equipoId';

  /// Lee el staff de una partida y deja un solo miembro por puesto.
  ///
  /// Las partidas v12 y anteriores no tienen la clave `staff`: se devuelve una
  /// lista vacía, sin gastar RNG y sin alterar el resto del estado.
  static List<MiembroStaff> _leerStaff(dynamic json) {
    final staff = <MiembroStaff>[];
    if (json is! List) return staff;
    for (final item in json) {
      if (item is! Map) continue;
      final miembro = MiembroStaff.fromJson(Map<String, dynamic>.from(item));
      if (staff.any((m) => m.rol == miembro.rol)) continue;
      staff.add(miembro);
    }
    return staff;
  }

  /// Convierte todo el estado a un mapa para guardarlo en JSON.
  Map<String, dynamic> toJson() {
    return {
      'version': versionFormato,
      'agente': agente.toJson(),
      'jugadores': jugadores.map((j) => j.toJson()).toList(),
      'equipos': equipos.map((e) => e.toJson()).toList(),
      'noticias': noticias.map((n) => n.toJson()).toList(),
      'competiciones': competiciones.map((c) => c.toJson()).toList(),
      'campeonesTemporada': campeonesTemporada,
      'torneos': torneos.map((t) => t.toJson()).toList(),
      'palmares': palmares.map((r) => r.toJson()).toList(),
      'premios': premios.map((p) => p.toJson()).toList(),
      'ofertas': ofertas.map((o) => o.toJson()).toList(),
      'agentesRivales': agentesRivales.map((a) => a.toJson()).toList(),
      'ojeadores': ojeadores.map((o) => o.toJson()).toList(),
      'staff': staff.map((m) => m.toJson()).toList(),
      'fichajesVentana': fichajesVentana,
      'eventosPendientes': eventosPendientes.map((e) => e.toJson()).toList(),
      'ultimaSemanaEvento': ultimaSemanaEvento,
      'frecuenciaEventos': frecuenciaEventos,
      'semanasInversor': semanasInversor,
      'semanasContactoGrande': semanasContactoGrande,
      'ceremoniaPendiente': ceremoniaPendiente,
      'semana': semana,
      'temporada': temporada,
      'siguienteIdJugador': siguienteIdJugador,
      'rondasNegociacion': rondasNegociacion,
      'paresBloqueados': paresBloqueados,
      'ingresosUltimaSemana': ingresosUltimaSemana,
      'gastosUltimaSemana': gastosUltimaSemana,
      'ingresosSemanaEnCurso': ingresosSemanaEnCurso,
      'gastosSemanaEnCurso': gastosSemanaEnCurso,
      'finDelJuego': finDelJuego,
    };
  }

  /// Reconstruye el estado desde un mapa JSON guardado.
  factory EstadoPartida.fromJson(Map<String, dynamic> json) {
    return EstadoPartida(
      agente: Agente.fromJson(json['agente'] as Map<String, dynamic>),
      jugadores: (json['jugadores'] as List)
          .map((j) => Jugador.fromJson(j as Map<String, dynamic>))
          .toList(),
      equipos: (json['equipos'] as List)
          .map((e) => Equipo.fromJson(e as Map<String, dynamic>))
          .toList(),
      noticias: (json['noticias'] as List)
          .map((n) => Noticia.fromJson(n as Map<String, dynamic>))
          .toList(),
      competiciones: ((json['competiciones'] as List?) ?? const [])
          .map((c) => Competicion.fromJson(c as Map<String, dynamic>))
          .toList(),
      campeonesTemporada: ((json['campeonesTemporada'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      torneos: ((json['torneos'] as List?) ?? const [])
          .map((t) => Torneo.fromJson(t as Map<String, dynamic>))
          .toList(),
      palmares: ((json['palmares'] as List?) ?? const [])
          .map((r) => RegistroCampeon.fromJson(r as Map<String, dynamic>))
          .toList(),
      premios: ((json['premios'] as List?) ?? const [])
          .map((p) => PremioIndividual.fromJson(p as Map<String, dynamic>))
          .toList(),
      ofertas: ((json['ofertas'] as List?) ?? const [])
          .map((o) => Oferta.fromJson(o as Map<String, dynamic>))
          .toList(),
      agentesRivales: ((json['agentesRivales'] as List?) ?? const [])
          .map((a) => AgenteRival.fromJson(a as Map<String, dynamic>))
          .toList(),
      ojeadores: ((json['ojeadores'] as List?) ?? const [])
          .map((o) => Ojeador.fromJson(o as Map<String, dynamic>))
          .toList(),
      staff: _leerStaff(json['staff']),
      fichajesVentana:
          (json['fichajesVentana'] as Map?)?.map(
            (k, v) => MapEntry(k as String, (v as num).toInt()),
          ) ??
          {},
      eventosPendientes: ((json['eventosPendientes'] as List?) ?? const [])
          .map((e) => EventoPendiente.fromJson(e as Map<String, dynamic>))
          .toList(),
      ultimaSemanaEvento:
          (json['ultimaSemanaEvento'] as Map?)?.map(
            (k, v) => MapEntry(k as String, (v as num).toInt()),
          ) ??
          {},
      frecuenciaEventos: json['frecuenciaEventos'] as String? ?? 'normal',
      semanasInversor: (json['semanasInversor'] as num?)?.toInt() ?? 0,
      semanasContactoGrande:
          (json['semanasContactoGrande'] as num?)?.toInt() ?? 0,
      ceremoniaPendiente: json['ceremoniaPendiente'] as bool? ?? false,
      semana: json['semana'] as int,
      temporada: json['temporada'] as int,
      // En partidas v3–v6 este campo no existe. Queda en 0 y el motor lo
      // reconstruye al cargar a partir del mayor id `p####` encontrado.
      siguienteIdJugador: (json['siguienteIdJugador'] as num?)?.toInt() ?? 0,
      rondasNegociacion:
          (json['rondasNegociacion'] as Map?)?.map(
            (k, v) => MapEntry(k as String, v as int),
          ) ??
          {},
      paresBloqueados:
          (json['paresBloqueados'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      ingresosUltimaSemana: json['ingresosUltimaSemana'] as int? ?? 0,
      gastosUltimaSemana: json['gastosUltimaSemana'] as int? ?? 0,
      ingresosSemanaEnCurso:
          (json['ingresosSemanaEnCurso'] as num?)?.toInt() ?? 0,
      gastosSemanaEnCurso: (json['gastosSemanaEnCurso'] as num?)?.toInt() ?? 0,
      finDelJuego: json['finDelJuego'] as bool? ?? false,
    );
  }
}
