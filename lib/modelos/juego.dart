// Lista de videojuegos del juego y sus roles.
// Cada videojuego tiene 5 roles (uno por titular en cada equipo).

/// Enum con los 4 videojuegos soportados.
/// Un "enum" es una lista fija de opciones que no cambia.
enum Juego {
  lol('League of Legends', 'LoL', ['Top', 'Jungla', 'Mid', 'ADC', 'Support']),
  valorant('Valorant', 'Valorant', [
    'Duelista',
    'Iniciador',
    'Controlador',
    'Centinela',
    'Flex',
  ]),
  cs2('Counter-Strike 2', 'CS2', [
    'IGL',
    'AWPer',
    'Entry',
    'Rifler',
    'Support',
  ]),
  dota2('Dota 2', 'Dota 2', [
    'Carry',
    'Mid',
    'Offlane',
    'Soporte 4',
    'Soporte 5',
  ]);

  const Juego(this.nombre, this.corto, this.roles);

  /// Nombre completo para mostrar (ej: "League of Legends").
  final String nombre;

  /// Nombre corto para etiquetas y chips (ej: "LoL").
  final String corto;

  /// Los 5 roles que existen dentro de este videojuego.
  final List<String> roles;

  /// Devuelve el juego a partir de su nombre interno (el que se guarda).
  /// Si algo no cuadra, devuelve League of Legends para no romper la app.
  static Juego porNombre(String nombre) {
    for (final juego in Juego.values) {
      if (juego.name == nombre) return juego;
    }
    return Juego.lol;
  }
}
