// Modelo de una noticia que aparece en la pestaña Noticias.

/// Tipo de noticia: define el ícono y el color con que se muestra.
enum TipoNoticia { fichaje, venta, progreso, dinero, evento, alerta }

/// Una noticia del juego (fichaje, venta, progreso, etc.).
class Noticia {
  Noticia({
    required this.semana,
    required this.temporada,
    required this.texto,
    required this.tipo,
  });

  /// Semana en que ocurrió (1 a 52).
  final int semana;

  /// Temporada en que ocurrió (empieza en 1).
  final int temporada;

  /// Texto que se muestra al jugador.
  final String texto;

  /// Tipo de noticia (para el ícono y color).
  final TipoNoticia tipo;

  /// Convierte la noticia a un mapa para poder guardarla en JSON.
  Map<String, dynamic> toJson() {
    return {
      'semana': semana,
      'temporada': temporada,
      'texto': texto,
      'tipo': tipo.name,
    };
  }

  /// Reconstruye una noticia desde un mapa JSON guardado.
  factory Noticia.fromJson(Map<String, dynamic> json) {
    return Noticia(
      semana: json['semana'] as int,
      temporada: json['temporada'] as int,
      texto: json['texto'] as String,
      tipo: TipoNoticia.values.firstWhere(
        (t) => t.name == json['tipo'],
        orElse: () => TipoNoticia.evento,
      ),
    );
  }
}
