// Modelo de una organización/equipo de esports.
import 'juego.dart';

/// Representa a un equipo. El campo "escudo" es el nombre del archivo de
/// imagen en assets/escudos/ (por ejemplo "t1.png").
class Equipo {
  Equipo({
    required this.id,
    required this.nombre,
    required this.juego,
    required this.region,
    required this.prestigio,
    required this.presupuesto,
    required this.colorPrincipal,
    required this.escudo,
    this.division = 1,
    this.liga = '',
    this.esReal = false,
    List<String>? rivales,
  }) : rivales = rivales ?? <String>[];

  /// Identificador único (ej: "t1", "fnatic_lol").
  final String id;

  /// Nombre visible (ej: "T1").
  final String nombre;

  /// Videojuego en el que compite.
  final Juego juego;

  /// Región (ej: "Corea", "Europa", "Norteamérica", "Brasil", "China").
  final String region;

  /// División en la que compite: 1 (Primera) o 2 (Segunda).
  int division;

  /// Nombre de la liga de su división (ej: "Liga Coreana").
  String liga;

  /// true = equipo real, false = generado por el juego.
  bool esReal;

  /// Ids de los equipos rivales (clásicos). Un partido entre rivales
  /// mueve más la moral y se marca en la interfaz.
  List<String> rivales;

  /// Nivel de prestigio, de 1 a 100.
  int prestigio;

  /// Dinero disponible para fichajes.
  int presupuesto;

  /// Color en formato 0xFFRRGGBB, usado en el círculo con iniciales.
  final int colorPrincipal;

  /// Nombre del archivo del escudo sin la carpeta (ej: "t1.png").
  final String escudo;

  /// Iniciales del equipo (ej: "TL" para "Team Liquid").
  /// Se usan cuando no hay imagen de escudo.
  String get iniciales {
    final palabras = nombre
        .replaceAll('-', ' ')
        .replaceAll('.', ' ')
        .split(' ')
        .where((p) => p.isNotEmpty)
        .toList();
    if (palabras.isEmpty) return '?';
    if (palabras.length == 1) {
      final p = palabras.first;
      return p.substring(0, p.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (palabras[0][0] + palabras[1][0]).toUpperCase();
  }

  /// Convierte el equipo a un mapa para guardarlo en JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'juego': juego.name,
      'region': region,
      'division': division,
      'liga': liga,
      'esReal': esReal,
      'prestigio': prestigio,
      'presupuesto': presupuesto,
      'colorPrincipal': colorPrincipal,
      'escudo': escudo,
      'rivales': rivales,
    };
  }

  /// Reconstruye un equipo desde un mapa JSON guardado.
  factory Equipo.fromJson(Map<String, dynamic> json) {
    return Equipo(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      juego: Juego.porNombre(json['juego'] as String),
      region: json['region'] as String,
      prestigio: json['prestigio'] as int,
      presupuesto: json['presupuesto'] as int,
      colorPrincipal: json['colorPrincipal'] as int,
      escudo: json['escudo'] as String,
      division: json['division'] as int? ?? 1,
      liga: json['liga'] as String? ?? '',
      esReal: json['esReal'] as bool? ?? false,
      rivales:
          (json['rivales'] as List?)?.map((e) => e as String).toList() ??
          <String>[],
    );
  }
}
