// Genera equipos ficticios para completar las divisiones que no llegan
// a 8 equipos. En 2ª División el prestigio va de 35 a 54; en 1ª, de 70 a 80
// para que las regiones con pocos equipos reales sigan siendo competitivas.
import 'dart:math';

import '../modelos/equipo.dart';
import '../modelos/juego.dart';
import 'formulas.dart';

/// Primera parte del nombre de un equipo ficticio.
const List<String> _prefijos = [
  'Andes',
  'Cóndor',
  'Nova',
  'Storm',
  'Titan',
  'Fénix',
  'Dragón',
  'Lobo',
  'Águila',
  'Jaguar',
  'Puma',
  'Kraken',
  'Vórtice',
  'Aurora',
  'Nexus',
  'Vega',
  'Cobalto',
  'Relámpago',
  'Sombra',
  'Espartano',
  'Guardián',
  'Corona',
  'Cielo',
  'Trueno',
  'Furia',
  'Oasis',
  'Cumbre',
  'Marea',
  'Ciclón',
  'Cometa',
  'Tornado',
  'Eclipse',
  'Halcón',
  'Pantera',
];

/// Segunda parte del nombre (a veces se omite).
const List<String> _sufijos = [
  'Esports',
  'Gaming',
  'Club',
  'Team',
  'eSports',
  'Academy',
  'Legion',
  'United',
  'Sport',
  'Empire',
  'Rift',
  'Arena',
  'Squad',
  'Pro',
];

/// Paleta de colores usados por los equipos ficticios.
const List<int> _colores = [
  0xFF1E88E5,
  0xFFE53935,
  0xFF43A047,
  0xFFFB8C00,
  0xFF8E24AA,
  0xFF00ACC1,
  0xFF3949AB,
  0xFFD81B60,
  0xFF6D4C41,
  0xFF546E7A,
  0xFF7CB342,
  0xFFF4511E,
  0xFF00897B,
  0xFF5E35B1,
  0xFFC0392B,
];

/// Devuelve un elemento aleatorio de una lista.
T _elegir<T>(Random rnd, List<T> lista) => lista[rnd.nextInt(lista.length)];

/// Crea un nick/nombre aleatorio para un equipo ficticio.
String generarNombreEquipo(Random rnd) {
  final prefijo = _elegir(rnd, _prefijos);
  // A veces se usa una sola palabra y a veces prefijo + sufijo.
  if (rnd.nextInt(4) == 0) return prefijo;
  return '$prefijo ${_elegir(rnd, _sufijos)}';
}

/// Genera un equipo ficticio para completar una división.
///
/// Los de 2ª División tienen prestigio 35–54. Los de 1ª necesitan un nivel
/// competitivo (70–80): antes también salían con 35–54 y los pocos equipos
/// reales de una región ganaban casi todas las temporadas.
/// El equipo empieza sin jugadores: la plantilla la arma el cargador.
Equipo generarEquipoFicticio(
  Random rnd, {
  required String id,
  required Juego juego,
  required String region,
  int division = 2,
  required String liga,
}) {
  final prestigio = division == 1
      ? 70 +
            rnd.nextInt(11) // 70..80
      : 35 + rnd.nextInt(20); // 35..54
  return Equipo(
    id: id,
    nombre: generarNombreEquipo(rnd),
    juego: juego,
    region: region,
    division: division,
    liga: liga,
    prestigio: prestigio,
    presupuesto: prestigio * presupuestoPorPrestigio,
    colorPrincipal: _elegir(rnd, _colores),
    escudo: '',
    esReal: false,
  );
}
