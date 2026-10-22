// Modelo de una oferta recibida (Parte 2D): puede ser un traspaso por uno
// de mis jugadores o una renovación de contrato propuesta por su equipo.

/// Tipo de oferta: un traspaso a otro equipo o una renovación de contrato.
enum TipoOferta { traspaso, renovacion }

/// Una oferta pendiente de respuesta. Yo decido si la acepto, la rechazo
/// o pido más dinero.
class Oferta {
  Oferta({
    required this.id,
    required this.tipo,
    required this.jugadorId,
    required this.equipoId,
    required this.monto,
    required this.salarioAnual,
    required this.semanasRestantes,
    required this.temporada,
    required this.semana,
  });

  /// Identificador único de la oferta.
  final String id;

  /// Traspaso o renovación.
  final TipoOferta tipo;

  /// Jugador por el que se hace la oferta.
  final String jugadorId;

  /// Equipo que hace la oferta.
  final String equipoId;

  /// Traspaso: precio ofrecido. Renovación: nuevo salario anual.
  int monto;

  /// Traspaso: salario ofrecido al jugador. Renovación: igual que monto.
  int salarioAnual;

  /// Semanas que quedan para responder. En renovación se mantiene
  /// mientras el contrato siga vigente.
  int semanasRestantes;

  /// Temporada y semana en que se generó la oferta.
  final int temporada;
  final int semana;

  /// Convierte la oferta a un mapa para guardarla en JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo': tipo.name,
      'jugadorId': jugadorId,
      'equipoId': equipoId,
      'monto': monto,
      'salarioAnual': salarioAnual,
      'semanasRestantes': semanasRestantes,
      'temporada': temporada,
      'semana': semana,
    };
  }

  /// Reconstruye una oferta desde un mapa JSON guardado.
  factory Oferta.fromJson(Map<String, dynamic> json) {
    return Oferta(
      id: json['id'] as String,
      tipo: TipoOferta.values.firstWhere(
        (t) => t.name == json['tipo'],
        orElse: () => TipoOferta.traspaso,
      ),
      jugadorId: json['jugadorId'] as String,
      equipoId: json['equipoId'] as String,
      monto: (json['monto'] as num).toInt(),
      salarioAnual: (json['salarioAnual'] as num).toInt(),
      semanasRestantes: (json['semanasRestantes'] as num).toInt(),
      temporada: (json['temporada'] as num).toInt(),
      semana: (json['semana'] as num).toInt(),
    );
  }
}
