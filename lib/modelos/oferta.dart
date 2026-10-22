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
    this.equipoOrigenId,
    this.mejorasRealizadas = 0,
    this.montoMaximo = 0,
  });

  /// Identificador único de la oferta.
  final String id;

  /// Traspaso o renovación.
  final TipoOferta tipo;

  /// Jugador por el que se hace la oferta.
  final String jugadorId;

  /// Equipo que hace la oferta.
  final String equipoId;

  /// Club en el que estaba el jugador cuando se creó la oferta. Sirve para
  /// detectar ofertas obsoletas si el jugador cambia de equipo (C4). En
  /// partidas antiguas puede ser null.
  final String? equipoOrigenId;

  /// Traspaso: precio ofrecido. Renovación: nuevo salario anual.
  int monto;

  /// Cuántas veces se ha pedido más por esta oferta (C5). Se guarda para
  /// limitar las subidas y evitar que el plazo se renueve sin fin.
  int mejorasRealizadas;

  /// Importe máximo que el comprador está dispuesto a pagar por esta oferta
  /// (C5). Incluye el valor de mercado y su presupuesto. 0 en ofertas viejas
  /// o renovaciones: el motor calcula el tope al pedir más.
  int montoMaximo;

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
      'equipoOrigenId': equipoOrigenId,
      'monto': monto,
      'salarioAnual': salarioAnual,
      'semanasRestantes': semanasRestantes,
      'mejorasRealizadas': mejorasRealizadas,
      'montoMaximo': montoMaximo,
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
      equipoOrigenId: json['equipoOrigenId'] as String?,
      monto: (json['monto'] as num).toInt(),
      salarioAnual: (json['salarioAnual'] as num).toInt(),
      semanasRestantes: (json['semanasRestantes'] as num).toInt(),
      mejorasRealizadas: (json['mejorasRealizadas'] as num?)?.toInt() ?? 0,
      montoMaximo: (json['montoMaximo'] as num?)?.toInt() ?? 0,
      temporada: (json['temporada'] as num).toInt(),
      semana: (json['semana'] as num).toInt(),
    );
  }
}
