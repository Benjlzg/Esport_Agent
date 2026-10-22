// Modelo de un torneo internacional: el Torneo de Mitad de Temporada y el
// Mundial (o "Major" en CS2). Guarda los participantes, los grupos (solo en
// el Mundial) y las rondas jugadas reutilizando el modelo ResultadoSerie.
import 'juego.dart';
import 'partido.dart';

/// Clase de torneo internacional.
enum TipoTorneo { mitad, mundial }

/// Un torneo internacional de un videojuego y una temporada.
class Torneo {
  Torneo({
    required this.id,
    required this.tipo,
    required this.juego,
    required this.temporada,
    required this.nombre,
    required this.participantes,
    Map<String, List<String>>? grupos,
    List<List<ResultadoSerie>>? rondas,
  }) : grupos = grupos ?? <String, List<String>>{},
       rondas = rondas ?? <List<ResultadoSerie>>[];

  /// Identificador único del torneo.
  final String id;

  /// Mitad de temporada o Mundial.
  final TipoTorneo tipo;

  /// Videojuego del torneo.
  final Juego juego;

  /// Temporada en la que se juega.
  final int temporada;

  /// Nombre visible ("Torneo de Mitad de Temporada" / "Mundial" / "Major").
  final String nombre;

  /// Ids de los equipos participantes, ordenados por prestigio.
  final List<String> participantes;

  /// Grupos del Mundial ("A", "B"...) con sus equipos. Vacío si no hay grupos.
  final Map<String, List<String>> grupos;

  /// Rondas jugadas, en orden cronológico. En el Mundial la primera ronda
  /// son los grupos; después vienen las rondas de eliminación directa.
  final List<List<ResultadoSerie>> rondas;

  /// Todas las series jugadas del torneo (grupos y eliminación).
  List<ResultadoSerie> get todosLosResultados =>
      rondas.expand((r) => r).toList();

  /// Rondas de eliminación directa (excluye los grupos).
  List<List<ResultadoSerie>> get rondasEliminacion => rondas
      .where((r) => r.isNotEmpty && !r.first.etapa.startsWith('Grupo'))
      .toList();

  /// Rondas de grupos del Mundial.
  List<List<ResultadoSerie>> get rondasGrupos => rondas
      .where((r) => r.isNotEmpty && r.first.etapa.startsWith('Grupo'))
      .toList();

  /// Campeón del torneo (solo cuando la final ya se jugó).
  String? get campeonId {
    if (rondas.isEmpty) return null;
    final ultima = rondas.last;
    // La final es una ronda con una única serie.
    if (ultima.length != 1) return null;
    return ultima.last.ganadorId;
  }

  /// Subcampeón del torneo (finalista perdedor).
  String? get subcampeonId {
    if (rondas.isEmpty) return null;
    final ultima = rondas.last;
    if (ultima.length != 1) return null;
    return ultima.last.perdedorId;
  }

  /// Número de rondas jugadas.
  int get rondasJugadas => rondas.length;

  /// ¿Ya se jugó la fase de grupos?
  bool get gruposJugados => rondasGrupos.isNotEmpty;

  /// Convierte el torneo a un mapa para guardarlo en JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo': tipo.name,
      'juego': juego.name,
      'temporada': temporada,
      'nombre': nombre,
      'participantes': participantes,
      'grupos': grupos,
      'rondas': rondas
          .map((ronda) => ronda.map((r) => r.toJson()).toList())
          .toList(),
    };
  }

  /// Reconstruye un torneo desde un mapa JSON guardado.
  factory Torneo.fromJson(Map<String, dynamic> json) {
    return Torneo(
      id: json['id'] as String,
      tipo: TipoTorneo.values.firstWhere(
        (t) => t.name == json['tipo'],
        orElse: () => TipoTorneo.mitad,
      ),
      juego: Juego.porNombre(json['juego'] as String),
      temporada: (json['temporada'] as num?)?.toInt() ?? 1,
      nombre: json['nombre'] as String,
      participantes: ((json['participantes'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      grupos:
          (json['grupos'] as Map?)?.map(
            (k, v) => MapEntry(
              k as String,
              (v as List).map((e) => e as String).toList(),
            ),
          ) ??
          <String, List<String>>{},
      rondas: ((json['rondas'] as List?) ?? const [])
          .map(
            (ronda) => (ronda as List)
                .map((r) => ResultadoSerie.fromJson(r as Map<String, dynamic>))
                .toList(),
          )
          .toList(),
    );
  }
}
