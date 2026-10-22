// Lista de videojuegos del juego y sus roles.
// Cada videojuego tiene 5 roles (uno por titular en cada equipo).
import 'package:flutter/foundation.dart';

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

  /// Último nombre inválido recibido. Sirve para que las pruebas y los
  /// diagnósticos puedan comprobar que un guardado traía un juego desconocido
  /// sin romper la carga (M9 de la auditoría).
  static String? ultimoNombreInvalido;

  /// Devuelve el juego a partir de su nombre interno (el que se guarda).
  /// Si algo no cuadra, avisa con `debugPrint` y devuelve League of Legends
  /// para no romper la app, en vez de convertir el error en silencio.
  static Juego porNombre(String nombre) {
    for (final juego in Juego.values) {
      if (juego.name == nombre) return juego;
    }
    ultimoNombreInvalido = nombre;
    debugPrint(
      'Juego.porNombre: "$nombre" no es un videojuego válido; '
      'se usará ${Juego.lol.name}.',
    );
    return Juego.lol;
  }
}
