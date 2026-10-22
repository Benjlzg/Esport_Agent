// Modelos del historial: los títulos (Palmarés) y los premios individuales
// que se entregan en la ceremonia de fin de temporada.
import 'juego.dart';

/// Distingue si un título es de una liga o de un torneo internacional.
enum TipoCampeon { liga, torneo }

/// Categorías de los premios individuales de fin de temporada.
enum CategoriaPremio {
  jugadorDelAnio,
  maximoEliminador,
  revelacion,
  equipoIdeal,
  agenteDelAnio,
}

/// Nombre visible de una categoría de premio individual.
String nombreCategoriaPremio(CategoriaPremio categoria) {
  switch (categoria) {
    case CategoriaPremio.jugadorDelAnio:
      return 'Jugador del Año';
    case CategoriaPremio.maximoEliminador:
      return 'Máximo Eliminador';
    case CategoriaPremio.revelacion:
      return 'Revelación del Año';
    case CategoriaPremio.equipoIdeal:
      return 'Mejor Equipo Ideal';
    case CategoriaPremio.agenteDelAnio:
      return 'Agente del Año';
  }
}

/// Un título ganado: queda registrado en el Palmarés histórico.
class RegistroCampeon {
  RegistroCampeon({
    required this.temporada,
    required this.juego,
    required this.descripcion,
    required this.tipo,
    required this.ganadorId,
  });

  /// Temporada en la que se ganó.
  final int temporada;

  /// Videojuego del título.
  final Juego juego;

  /// Descripción (ej: "Liga Coreana (Split 1)").
  final String descripcion;

  /// Liga o torneo.
  final TipoCampeon tipo;

  /// Id del equipo campeón.
  final String ganadorId;

  /// Convierte el registro a un mapa para guardarlo en JSON.
  Map<String, dynamic> toJson() {
    return {
      'temporada': temporada,
      'juego': juego.name,
      'descripcion': descripcion,
      'tipo': tipo.name,
      'ganadorId': ganadorId,
    };
  }

  /// Reconstruye un registro desde un mapa JSON guardado.
  factory RegistroCampeon.fromJson(Map<String, dynamic> json) {
    return RegistroCampeon(
      temporada: (json['temporada'] as num?)?.toInt() ?? 1,
      juego: Juego.porNombre(json['juego'] as String),
      descripcion: json['descripcion'] as String,
      tipo: TipoCampeon.values.firstWhere(
        (t) => t.name == json['tipo'],
        orElse: () => TipoCampeon.liga,
      ),
      ganadorId: json['ganadorId'] as String,
    );
  }
}

/// Un premio individual de fin de temporada.
class PremioIndividual {
  PremioIndividual({
    required this.temporada,
    this.juego,
    required this.categoria,
    this.jugadorId,
    this.rol,
    required this.detalle,
    this.nombreAgente,
  });

  /// Temporada del premio.
  final int temporada;

  /// Videojuego del premio (null en Agente del Año, que es global).
  final Juego? juego;

  /// Categoría del premio.
  final CategoriaPremio categoria;

  /// Id del jugador premiado (si aplica).
  final String? jugadorId;

  /// Rol del jugador premiado (para el Equipo Ideal).
  final String? rol;

  /// Texto descriptivo para la ceremonia (ej: "Faker (T1) — nota 8,4").
  final String detalle;

  /// Nombre del agente premiado (solo en Agente del Año).
  final String? nombreAgente;

  /// Convierte el premio a un mapa para guardarlo en JSON.
  Map<String, dynamic> toJson() {
    return {
      'temporada': temporada,
      'juego': juego?.name,
      'categoria': categoria.name,
      'jugadorId': jugadorId,
      'rol': rol,
      'detalle': detalle,
      'nombreAgente': nombreAgente,
    };
  }

  /// Reconstruye un premio desde un mapa JSON guardado.
  factory PremioIndividual.fromJson(Map<String, dynamic> json) {
    final juego = json['juego'] as String?;
    return PremioIndividual(
      temporada: (json['temporada'] as num?)?.toInt() ?? 1,
      juego: juego == null ? null : Juego.porNombre(juego),
      categoria: CategoriaPremio.values.firstWhere(
        (c) => c.name == json['categoria'],
        orElse: () => CategoriaPremio.jugadorDelAnio,
      ),
      jugadorId: json['jugadorId'] as String?,
      rol: json['rol'] as String?,
      detalle: json['detalle'] as String,
      nombreAgente: json['nombreAgente'] as String?,
    );
  }
}
