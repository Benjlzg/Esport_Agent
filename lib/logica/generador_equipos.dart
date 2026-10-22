// Genera equipos ficticios para completar las divisiones que no llegan
// a 8 equipos. Los equipos ficticios son de 2ª División y su prestigio
// va de 35 a 54 (ver PLAN_2A.md, sección 9).
import 'dart:math';

import '../modelos/equipo.dart';
import '../modelos/juego.dart';

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

/// Genera un equipo ficticio de 2ª División (prestigio 35–54).
/// El equipo empieza sin jugadores: la plantilla la arma el cargador.
Equipo generarEquipoFicticio(
  Random rnd, {
  required String id,
  required Juego juego,
  required String region,
  int division = 2,
  required String liga,
}) {
  final prestigio = 35 + rnd.nextInt(20); // 35..54
  return Equipo(
    id: id,
    nombre: generarNombreEquipo(rnd),
    juego: juego,
    region: region,
    division: division,
    liga: liga,
    prestigio: prestigio,
    presupuesto: prestigio * 20000,
    colorPrincipal: _elegir(rnd, _colores),
    escudo: '',
    esReal: false,
  );
}
