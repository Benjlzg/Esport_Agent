// Filtros y ordenaciones del mercado y de los equipos.
//
// Se sacaron de las pestañas para poder probarlos sin widgets (sección 5 de
// la auditoría) y para corregir M1: un agente libre no tiene equipo, así que
// su región debe salir de `jugador.region`, no del club actual.
import '../modelos/equipo.dart';
import '../modelos/juego.dart';
import '../modelos/jugador.dart';
import 'ojeadores.dart';

/// Opciones de orden de la lista del mercado.
enum OrdenMercado { valor, habilidad, potencial, edad }

/// Región de un jugador: la de su club si tiene equipo y, si está libre, la
/// suya propia. Así el filtro de región no deja la lista vacía con
/// "Solo libres" activo (M1).
String? regionDeJugador(Jugador jugador, Map<String, Equipo> equipos) {
  final equipoId = jugador.equipoId;
  if (equipoId != null) {
    final equipo = equipos[equipoId];
    if (equipo != null) return equipo.region;
  }
  return jugador.region;
}

/// Filtra y ordena los jugadores del mercado.
List<Jugador> filtrarJugadoresMercado({
  required Iterable<Jugador> jugadores,
  required Map<String, Equipo> equipos,
  Juego? juego,
  String? region,
  bool soloLibres = true,
  OrdenMercado orden = OrdenMercado.valor,
}) {
  final lista = jugadores.where((jugador) {
    // Los talentos ocultos se muestran aparte, solo si hay un ojeador en su
    // región; nunca se mezclan con el mercado normal. Los candidatos de la
    // academia y sus jóvenes tampoco aparecen en el Mercado.
    if (jugador.oculto || jugador.candidatoAcademia || jugador.enAcademia) {
      return false;
    }
    if (juego != null && jugador.juego != juego) return false;
    if (soloLibres && jugador.equipoId != null) return false;
    if (region != null && regionDeJugador(jugador, equipos) != region) {
      return false;
    }
    return true;
  }).toList();

  switch (orden) {
    case OrdenMercado.valor:
      lista.sort((a, b) => b.valorMercado.compareTo(a.valorMercado));
    case OrdenMercado.habilidad:
      lista.sort((a, b) => b.habilidad.compareTo(a.habilidad));
    case OrdenMercado.potencial:
      // Se ordena por el punto medio del rango visible, nunca por el real.
      lista.sort((a, b) {
        final porMedio = puntoMedioPotencial(b)
            .compareTo(puntoMedioPotencial(a));
        if (porMedio != 0) return porMedio;
        return b.habilidad.compareTo(a.habilidad);
      });
    case OrdenMercado.edad:
      lista.sort((a, b) => a.edad.compareTo(b.edad));
  }
  return lista;
}

/// Filtra los equipos por videojuego, región y división.
List<Equipo> filtrarEquipos({
  required Iterable<Equipo> equipos,
  Juego? juego,
  String? region,
  int? division,
}) {
  return equipos.where((equipo) {
    if (juego != null && equipo.juego != juego) return false;
    if (region != null && equipo.region != region) return false;
    if (division != null && equipo.division != division) return false;
    return true;
  }).toList();
}
