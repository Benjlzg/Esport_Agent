// Genera jugadores aleatorios: agentes libres, jóvenes talentos y
// rellenos de plantilla para los equipos.
import 'dart:math';

import '../datos/nombres_aleatorios.dart';
import '../modelos/equipo.dart';
import '../modelos/juego.dart';
import '../modelos/jugador.dart';
import 'formulas.dart';
import 'ojeadores.dart';

/// Devuelve un elemento aleatorio de una lista.
T _elegir<T>(Random rnd, List<T> lista) => lista[rnd.nextInt(lista.length)];

/// Crea un nick aleatorio combinando una palabra base, un sufijo y/o número.
String generarNick(Random rnd) {
  final base = _elegir(rnd, nicksBase);
  final estilo = rnd.nextInt(3);
  if (estilo == 0) return base;
  if (estilo == 1) return '$base${_elegir(rnd, nicksSufijo)}';
  return '$base${rnd.nextInt(99)}';
}

/// Devuelve un nick que todavía no esté en [usados] y lo anota en el conjunto.
///
/// Si el nick aleatorio ya existe, se agrega un número al final
/// ("Drift", "Drift2", "Drift3"...). Así no cambia el orden de las tiradas
/// aleatorias de la simulación.
String generarNickUnico(Random rnd, Set<String> usados) {
  final base = generarNick(rnd);
  var candidato = base;
  var numero = 2;
  while (usados.contains(candidato)) {
    candidato = '$base$numero';
    numero++;
  }
  usados.add(candidato);
  return candidato;
}

/// Reserva un nick que ya viene escrito (por ejemplo, de un JSON de equipos).
/// Si está repetido, agrega un número igual que [generarNickUnico].
String reservarNickUnico(String nick, Set<String> usados) {
  var candidato = nick;
  var numero = 2;
  while (usados.contains(candidato)) {
    candidato = '$nick$numero';
    numero++;
  }
  usados.add(candidato);
  return candidato;
}

/// Corrige una lista de jugadores que ya tenga nicks repetidos (partidas
/// viejas o datos iniciales). Conserva el primero y renombra los siguientes.
void asegurarNicksUnicos(Iterable<Jugador> jugadores) {
  final usados = <String>{};
  for (final jugador in jugadores) {
    jugador.nick = reservarNickUnico(jugador.nick, usados);
  }
}

/// Completa los datos de valor y salario de un jugador recién creado.
void _calcularEconomia(Jugador jugador) {
  jugador.valorMercado = valorMercadoDe(jugador);
  jugador.salarioAnual = calcularSalarioAnual(jugador.valorMercado);
}

/// Genera un agente libre joven (no pertenece a ningún equipo).
/// Edad 16 a 24 · habilidad 35 a 70 · potencial habilidad + 5 a 30 (máx 99).
Jugador generarJugadorLibre(
  Random rnd, {
  required String id,
  String? region,
  required Set<String> nicksUsados,
}) {
  final juego = _elegir(rnd, Juego.values);
  final edad = 16 + rnd.nextInt(9); // 16..24
  final habilidad = 35 + rnd.nextInt(36); // 35..70
  final potencial = min(99, habilidad + 5 + rnd.nextInt(26)); // +5..30

  final jugador = Jugador(
    id: id,
    nick: generarNickUnico(rnd, nicksUsados),
    nombreReal: '${_elegir(rnd, nombres)} ${_elegir(rnd, apellidos)}',
    pais: _elegir(rnd, paises),
    edad: edad,
    juego: juego,
    rol: _elegir(rnd, juego.roles),
    habilidad: habilidad,
    potencial: potencial,
    moral: 70,
    equipoId: null,
    salarioAnual: 0,
    semanasContrato: 0,
    representadoPorMi: false,
    esReal: false,
    region: region,
  );
  _calcularEconomia(jugador);
  // Todo jugador nuevo nace con su error de potencial y su rango inicial.
  inicializarPotencialJugador(jugador, rnd);
  return jugador;
}

/// Genera un joven talento libre de una región concreta de un videojuego.
/// Potencial entre 60 y 95 y los nombres del perfil de esa región.
Jugador generarJovenDeRegion(
  Random rnd, {
  required String id,
  required Juego juego,
  required String region,
  required Set<String> nicksUsados,
}) {
  final perfil = perfilDeRegion(region);
  final edad = 16 + rnd.nextInt(6); // 16..21
  final potencial = 60 + rnd.nextInt(36); // 60..95
  final margen = 5 + rnd.nextInt(26); // 5..30 por debajo del potencial
  final habilidad = max(25, potencial - margen);

  final jugador = Jugador(
    id: id,
    nick: generarNickUnico(rnd, nicksUsados),
    nombreReal:
        '${_elegir(rnd, perfil.nombres)} ${_elegir(rnd, perfil.apellidos)}',
    pais: _elegir(rnd, perfil.paises),
    edad: edad,
    juego: juego,
    rol: _elegir(rnd, juego.roles),
    habilidad: habilidad,
    potencial: potencial,
    moral: 70,
    equipoId: null,
    salarioAnual: 0,
    semanasContrato: 0,
    representadoPorMi: false,
    esReal: false,
    region: region,
  );
  _calcularEconomia(jugador);
  inicializarPotencialJugador(jugador, rnd);
  return jugador;
}

/// Genera un candidato para la academia (Parte 3E).
///
/// Edad 15–17, habilidad 25–45 y potencial 60–95. Nace marcado como candidato
/// para que solo se vea en la pantalla Academia y para que la IA, los rivales
/// y el mantenimiento no lo confundan con un agente libre normal.
Jugador generarCandidatoAcademia(
  Random rnd, {
  required String id,
  required Juego juego,
  String? region,
  required Set<String> nicksUsados,
}) {
  final perfil = perfilDeRegion(region ?? 'General');
  final edad = 15 + rnd.nextInt(3); // 15..17
  final habilidad = 25 + rnd.nextInt(21); // 25..45
  final potencial = max(habilidad, 60 + rnd.nextInt(36)); // 60..95

  final jugador = Jugador(
    id: id,
    nick: generarNickUnico(rnd, nicksUsados),
    nombreReal:
        '${_elegir(rnd, perfil.nombres)} ${_elegir(rnd, perfil.apellidos)}',
    pais: _elegir(rnd, perfil.paises),
    edad: edad,
    juego: juego,
    rol: _elegir(rnd, juego.roles),
    habilidad: habilidad,
    potencial: potencial,
    moral: 70,
    equipoId: null,
    salarioAnual: 0,
    semanasContrato: 0,
    representadoPorMi: false,
    esReal: false,
    region: region,
    candidatoAcademia: true,
  );
  _calcularEconomia(jugador);
  inicializarPotencialJugador(jugador, rnd);
  return jugador;
}

/// Genera un jugador para rellenar el rol que falta en un equipo.
/// La habilidad se basa en el prestigio del equipo (±8) y los nombres
/// se eligen según la región del equipo.
Jugador generarJugadorParaEquipo(
  Random rnd, {
  required String id,
  required Equipo equipo,
  required String rol,
  int ajusteHabilidad = 0,
  required Set<String> nicksUsados,
}) {
  final perfil = perfilDeRegion(equipo.region);
  final edad = 17 + rnd.nextInt(11); // 17..27
  var habilidad = equipo.prestigio + ajusteHabilidad + (rnd.nextInt(17) - 8);
  habilidad = habilidad.clamp(1, 99);
  final potencial = min(99, habilidad + 2 + rnd.nextInt(19)); // +2..20

  final jugador = Jugador(
    id: id,
    nick: generarNickUnico(rnd, nicksUsados),
    nombreReal:
        '${_elegir(rnd, perfil.nombres)} ${_elegir(rnd, perfil.apellidos)}',
    pais: _elegir(rnd, perfil.paises),
    edad: edad,
    juego: equipo.juego,
    rol: rol,
    habilidad: habilidad,
    potencial: potencial,
    moral: 70,
    equipoId: equipo.id,
    salarioAnual: 0,
    semanasContrato: 52 + rnd.nextInt(53), // 52..104 semanas
    representadoPorMi: false,
    esReal: false,
    region: equipo.region,
  );
  _calcularEconomia(jugador);
  inicializarPotencialJugador(jugador, rnd);
  return jugador;
}

/// Genera una lista de jóvenes talentos libres (para el inicio de temporada).
List<Jugador> generarJovenes(
  Random rnd, {
  required int cantidad,
  required int idBase,
  required Set<String> nicksUsados,
}) {
  final lista = <Jugador>[];
  for (var i = 0; i < cantidad; i++) {
    lista.add(
      generarJugadorLibre(
        rnd,
        id: 'gen_${idBase + i}',
        nicksUsados: nicksUsados,
      ),
    );
  }
  return lista;
}
