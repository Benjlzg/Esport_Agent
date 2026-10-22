// Modelo de una región de un videojuego y los nombres de sus dos ligas
// (1ª y 2ª División). Los nombres de liga son inventados y editables.
class Region {
  const Region({
    required this.nombre,
    required this.ligaPrimera,
    required this.ligaSegunda,
  });

  /// Nombre de la región (ej: "Corea", "Europa").
  final String nombre;

  /// Nombre de la liga de 1ª División (ej: "Liga Coreana").
  final String ligaPrimera;

  /// Nombre de la liga de 2ª División (ej: "Liga Coreana - Segunda").
  final String ligaSegunda;

  /// Devuelve el nombre de la liga que corresponde a una división.
  String ligaDe(int division) => division <= 1 ? ligaPrimera : ligaSegunda;

  /// Reconstruye una región desde una entrada de regiones.json.
  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      nombre: json['region'] as String,
      ligaPrimera: json['ligaPrimera'] as String,
      ligaSegunda: json['ligaSegunda'] as String,
    );
  }
}
