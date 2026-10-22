// Modelo de una serie (partido al mejor de 3 o de 5) ya jugada.
// Se guarda dentro de una Competicion para poder derivar la tabla de
// posiciones, la forma de los equipos y el historial directo.

/// Resultado de una serie entre dos equipos.
class ResultadoSerie {
  ResultadoSerie({
    required this.fecha,
    required this.etapa,
    required this.localId,
    required this.visitanteId,
    required this.mapasLocal,
    required this.mapasVisitante,
    required this.ganadorId,
  });

  /// Número de fecha dentro del split (1 a 14) o 0 en playoffs.
  final int fecha;

  /// Etapa a la que pertenece (ej: "Liga Split 1", "Playoffs Split 1").
  final String etapa;

  /// Id del equipo local.
  final String localId;

  /// Id del equipo visitante.
  final String visitanteId;

  /// Mapas ganados por el local.
  final int mapasLocal;

  /// Mapas ganados por el visitante.
  final int mapasVisitante;

  /// Id del equipo que ganó la serie.
  final String ganadorId;

  /// Id del equipo que perdió la serie.
  String get perdedorId => ganadorId == localId ? visitanteId : localId;

  /// ¿Ganó la serie el equipo indicado?
  bool gano(String equipoId) => ganadorId == equipoId;

  /// ¿Participó el equipo indicado en esta serie?
  bool participa(String equipoId) =>
      equipoId == localId || equipoId == visitanteId;

  /// Mapas ganados por el equipo indicado.
  int mapasDe(String equipoId) =>
      equipoId == localId ? mapasLocal : mapasVisitante;

  /// Mapas recibidos por el equipo indicado.
  int mapasContra(String equipoId) =>
      equipoId == localId ? mapasVisitante : mapasLocal;

  /// Convertir a mapa para guardar en JSON.
  Map<String, dynamic> toJson() {
    return {
      'fecha': fecha,
      'etapa': etapa,
      'localId': localId,
      'visitanteId': visitanteId,
      'mapasLocal': mapasLocal,
      'mapasVisitante': mapasVisitante,
      'ganadorId': ganadorId,
    };
  }

  /// Reconstruir una serie desde un mapa JSON guardado.
  factory ResultadoSerie.fromJson(Map<String, dynamic> json) {
    return ResultadoSerie(
      fecha: (json['fecha'] as num?)?.toInt() ?? 0,
      etapa: json['etapa'] as String,
      localId: json['localId'] as String,
      visitanteId: json['visitanteId'] as String,
      mapasLocal: (json['mapasLocal'] as num).toInt(),
      mapasVisitante: (json['mapasVisitante'] as num).toInt(),
      ganadorId: json['ganadorId'] as String,
    );
  }
}
