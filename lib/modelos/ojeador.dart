// Modelo de un ojeador de la agencia (Parte 3C).
//
// Cada ojeador cubre un videojuego y una región. Su nivel (1–5) reduce el
// rango de potencial que puede descubrir y su salario se cobra cada semana.
import 'juego.dart';

/// Ojeador contratado por la agencia.
class Ojeador {
  Ojeador({
    required this.id,
    required this.nombre,
    required this.juego,
    required this.region,
    required this.nivel,
    this.semanasContratado = 0,
  });

  /// Identificador único (ej: "o001").
  final String id;

  /// Nombre visible del ojeador.
  String nombre;

  /// Videojuego que trabaja.
  Juego juego;

  /// Región que cubre.
  String region;

  /// Nivel de 1 a 5. Cuanto más alto, más estrecha el rango de potencial.
  int nivel;

  /// Semanas que lleva contratado. Se muestra en la pantalla de Ojeadores y
  /// se usa para la nota de precisión.
  int semanasContratado;

  /// Convierte el ojeador a un mapa para guardarlo en JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'juego': juego.name,
      'region': region,
      'nivel': nivel,
      'semanasContratado': semanasContratado,
    };
  }

  /// Reconstruye un ojeador desde JSON. Un nivel fuera de rango se acota a
  /// 1–5 para no romper partidas modificadas a mano.
  factory Ojeador.fromJson(Map<String, dynamic> json) {
    return Ojeador(
      id: json['id'] as String? ?? 'o000',
      nombre: json['nombre'] as String? ?? 'Ojeador',
      juego: Juego.porNombre(json['juego'] as String? ?? 'lol'),
      region: json['region'] as String? ?? 'Desconocida',
      nivel: ((json['nivel'] as num?)?.toInt() ?? 1).clamp(1, 5),
      semanasContratado: (json['semanasContratado'] as num?)?.toInt() ?? 0,
    );
  }
}
