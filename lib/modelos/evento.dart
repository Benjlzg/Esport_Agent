// Modelo de los eventos aleatorios (Parte 2E).
//
// El catálogo de eventos vive en `lib/logica/eventos.dart`; aquí solo se
// guarda la frecuencia elegida y los eventos que están pendientes de resolver.

/// Frecuencia con la que aparecen los eventos aleatorios.
enum FrecuenciaEventos {
  baja('Baja', 0.5),
  normal('Normal', 1.0),
  alta('Alta', 2.0);

  const FrecuenciaEventos(this.nombre, this.multiplicador);

  /// Texto visible en Ajustes.
  final String nombre;

  /// Multiplicador que se aplica a las probabilidades semanales.
  final double multiplicador;

  /// Devuelve la frecuencia por su nombre guardado. Si no existe, usa normal.
  static FrecuenciaEventos porNombre(String? nombre) {
    for (final frecuencia in FrecuenciaEventos.values) {
      if (frecuencia.name == nombre) return frecuencia;
    }
    return FrecuenciaEventos.normal;
  }
}

/// Un evento generado que todavía no se ha resuelto.
///
/// Los textos se guardan ya interpolados (con el nick del jugador) para que la
/// ventana emergente pueda mostrarlos aunque el jugador cambie de nombre.
class EventoPendiente {
  EventoPendiente({
    required this.id,
    required this.definicionId,
    this.jugadorId,
    required this.titulo,
    required this.descripcion,
    required this.esDecision,
    this.opcionA,
    this.opcionB,
    this.costoBaseA = 0,
    this.costoBaseB = 0,
    this.ingresoBaseA = 0,
    this.ingresoBaseB = 0,
    required this.temporada,
    required this.semana,
  });

  /// Identificador único del evento pendiente (ej: "ev_1_23_001").
  final String id;

  /// Identificador del evento dentro del catálogo de `eventos.dart`.
  final String definicionId;

  /// Jugador afectado. Es null en los eventos de agencia.
  final String? jugadorId;

  /// Título visible.
  final String titulo;

  /// Descripción visible con el nick ya interpolado.
  final String descripcion;

  /// true si tiene dos opciones; false si solo se cierra con "Entendido".
  final bool esDecision;

  /// Textos de las opciones A y B (B solo existe si hay decisión).
  final String? opcionA;
  final String? opcionB;

  /// Costo base de cada opción antes de limitarlo al 30 % del dinero.
  final int costoBaseA;
  final int costoBaseB;

  /// Dinero que PAGA el evento con cada opción (patrocinios, inversores...).
  /// Los ingresos no se limitan ni piden confirmación (corrección 2.5 A1).
  final int ingresoBaseA;
  final int ingresoBaseB;

  /// Temporada y semana en que se generó.
  final int temporada;
  final int semana;

  /// Costo base de la opción indicada (0 para la opción B o si no cuesta).
  int costoBaseDe(int opcion) => opcion == 0 ? costoBaseA : costoBaseB;

  /// Ingreso de la opción indicada (0 si no da dinero).
  int ingresoDe(int opcion) => opcion == 0 ? ingresoBaseA : ingresoBaseB;

  /// Convierte el evento a un mapa para guardarlo en JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'definicionId': definicionId,
      'jugadorId': jugadorId,
      'titulo': titulo,
      'descripcion': descripcion,
      'esDecision': esDecision,
      'opcionA': opcionA,
      'opcionB': opcionB,
      'costoBaseA': costoBaseA,
      'costoBaseB': costoBaseB,
      'ingresoBaseA': ingresoBaseA,
      'ingresoBaseB': ingresoBaseB,
      'temporada': temporada,
      'semana': semana,
    };
  }

  /// Reconstruye un evento desde un mapa JSON guardado. Todos los campos
  /// nuevos se leen de forma tolerante para no romper partidas antiguas.
  factory EventoPendiente.fromJson(Map<String, dynamic> json) {
    final opcionB = json['opcionB'] as String?;
    return EventoPendiente(
      id: json['id'] as String? ?? '',
      definicionId: json['definicionId'] as String? ?? '',
      jugadorId: json['jugadorId'] as String?,
      titulo: json['titulo'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      esDecision: json['esDecision'] as bool? ?? opcionB != null,
      opcionA: json['opcionA'] as String?,
      opcionB: opcionB,
      costoBaseA: (json['costoBaseA'] as num?)?.toInt() ?? 0,
      costoBaseB: (json['costoBaseB'] as num?)?.toInt() ?? 0,
      ingresoBaseA: (json['ingresoBaseA'] as num?)?.toInt() ?? 0,
      ingresoBaseB: (json['ingresoBaseB'] as num?)?.toInt() ?? 0,
      temporada: (json['temporada'] as num?)?.toInt() ?? 1,
      semana: (json['semana'] as num?)?.toInt() ?? 1,
    );
  }
}
