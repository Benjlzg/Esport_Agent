// Modelo del agente: es el jugador humano (tú).

/// Representa al agente que maneja el usuario.
class Agente {
  Agente({
    required this.nombre,
    required this.pais,
    this.dinero = 50000,
    this.reputacion = 10,
    this.semanasEnNegativo = 0,
  });

  /// Nombre del agente.
  String nombre;

  /// País del agente.
  String pais;

  /// Dinero actual. Empieza en 50.000.
  int dinero;

  /// Reputación, de 0 a 100. Empieza en 10.
  int reputacion;

  /// Semanas seguidas con el dinero en negativo (para la bancarrota).
  int semanasEnNegativo;

  /// Convierte al agente a un mapa para guardarlo en JSON.
  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'pais': pais,
      'dinero': dinero,
      'reputacion': reputacion,
      'semanasEnNegativo': semanasEnNegativo,
    };
  }

  /// Reconstruye al agente desde un mapa JSON guardado.
  factory Agente.fromJson(Map<String, dynamic> json) {
    return Agente(
      nombre: json['nombre'] as String,
      pais: json['pais'] as String,
      dinero: json['dinero'] as int,
      reputacion: json['reputacion'] as int,
      semanasEnNegativo: json['semanasEnNegativo'] as int,
    );
  }
}
