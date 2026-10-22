// Índices del mundo (corrección I9 y parte de I11).
//
// Antes el motor buscaba jugadores recorriendo la lista completa en cada
// consulta. Ahora mantiene:
//  - jugadores y equipos por id;
//  - la plantilla de cada equipo;
//  - el titular de cada equipo+rol;
//  - mis representados agrupados por equipo.
//
// Así el mercado puede comprobar si falta un titular sin recorrer todos los
// jugadores por cada equipo y rol.
import 'dart:math';

import '../modelos/estado_partida.dart';
import '../modelos/equipo.dart';
import '../modelos/jugador.dart';

/// Guarda índices derivados del estado. No se serializa: se reconstruye al
/// cargar una partida y se actualiza en cada fichaje o cambio de plantilla.
class IndicesMundo {
  final Map<String, Jugador> _jugadores = {};
  final Map<String, Equipo> _equipos = {};
  final Map<String, List<Jugador>> _porEquipo = {};
  final Map<String, Map<String, Jugador>> _titularesPorEquipoRol = {};
  final Map<String, List<Jugador>> _representadosPorEquipo = {};

  /// Última ubicación conocida de cada jugador, para poder quitar sus datos
  /// viejos de los índices cuando cambia de equipo o de rol.
  final Map<String, ({String equipoId, String rol, bool suplente})> _ubicacion =
      {};

  /// Contador de ids reconstruido desde los ids `p####` existentes.
  int siguienteIdJugador = 0;

  Map<String, Jugador> get jugadores => _jugadores;
  Map<String, Equipo> get equipos => _equipos;

  /// Jugadores de un equipo (titulares y suplentes).
  List<Jugador> plantillaDe(String equipoId) =>
      _porEquipo[equipoId] ?? const [];

  /// Titular de un equipo en un rol, o null si el hueco está vacío.
  Jugador? titularDe(String equipoId, String rol) =>
      _titularesPorEquipoRol[equipoId]?[rol];

  /// Mesas de titulares por equipo y rol. Se usa para pasar una vez al mercado
  /// en lugar de recorrer la lista global en cada comprobación.
  Map<String, Map<String, Jugador>> get titularesPorEquipoRol =>
      _titularesPorEquipoRol;

  /// Mis jugadores representados agrupados por el equipo en el que juegan.
  Map<String, List<Jugador>> get representadosPorEquipo =>
      _representadosPorEquipo;

  Jugador? jugadorPorId(String id) => _jugadores[id];
  Equipo? equipoPorId(String id) => _equipos[id];

  /// Reconstruye todos los índices desde el estado de la partida.
  void reconstruir(EstadoPartida estado) {
    _jugadores.clear();
    _equipos.clear();
    _porEquipo.clear();
    _titularesPorEquipoRol.clear();
    _representadosPorEquipo.clear();
    _ubicacion.clear();

    var siguiente = estado.siguienteIdJugador;
    for (final equipo in estado.equipos) {
      _equipos[equipo.id] = equipo;
    }
    for (final jugador in estado.jugadores) {
      _jugadores[jugador.id] = jugador;
      _agregarAUbicacion(jugador);
      if (jugador.id.startsWith('p')) {
        final numero = int.tryParse(jugador.id.substring(1));
        if (numero != null && numero >= siguiente) siguiente = numero + 1;
      }
    }
    for (final equipoId in _porEquipo.keys) {
      _reindexarTitulares(equipoId);
    }
    siguienteIdJugador = siguiente;
  }

  /// Registra un jugador nuevo (por ejemplo, un reemplazo generado).
  void registrar(Jugador jugador) {
    _jugadores[jugador.id] = jugador;
    _agregarAUbicacion(jugador);
    _reindexarTitulares(jugador.equipoId);
  }

  /// Actualiza la ubicación de un jugador después de un traspaso, un cambio de
  /// rol, de suplente o de representación.
  void actualizar(Jugador jugador) {
    _jugadores[jugador.id] = jugador;
    final anterior = _ubicacion[jugador.id];
    _quitarDeUbicacion(jugador.id, anterior);
    if (jugador.equipoId != null) {
      _agregarAUbicacion(jugador);
    }
    _reindexarTitulares(anterior?.equipoId);
    _reindexarTitulares(jugador.equipoId);
  }

  /// Quita un jugador retirado o eliminado del mundo.
  void eliminar(Jugador jugador) {
    final anterior = _ubicacion[jugador.id];
    _jugadores.remove(jugador.id);
    _quitarDeUbicacion(jugador.id, anterior);
    _reindexarTitulares(anterior?.equipoId);
  }

  /// Vacía los índices (al borrar la partida).
  void limpiar() {
    _jugadores.clear();
    _equipos.clear();
    _porEquipo.clear();
    _titularesPorEquipoRol.clear();
    _representadosPorEquipo.clear();
    _ubicacion.clear();
    siguienteIdJugador = 0;
  }

  void _agregarAUbicacion(Jugador jugador) {
    final equipoId = jugador.equipoId;
    if (equipoId == null) {
      _ubicacion.remove(jugador.id);
      return;
    }
    _porEquipo.putIfAbsent(equipoId, () => <Jugador>[]).add(jugador);
    _ubicacion[jugador.id] = (
      equipoId: equipoId,
      rol: jugador.rol,
      suplente: jugador.suplente,
    );
    if (jugador.representadoPorMi) {
      _representadosPorEquipo
          .putIfAbsent(equipoId, () => <Jugador>[])
          .add(jugador);
    }
  }

  void _quitarDeUbicacion(
    String jugadorId,
    ({String equipoId, String rol, bool suplente})? anterior,
  ) {
    if (anterior == null) return;
    final lista = _porEquipo[anterior.equipoId];
    if (lista != null) {
      lista.removeWhere((j) => j.id == jugadorId);
      if (lista.isEmpty) _porEquipo.remove(anterior.equipoId);
    }
    final representados = _representadosPorEquipo[anterior.equipoId];
    if (representados != null) {
      representados.removeWhere((j) => j.id == jugadorId);
      if (representados.isEmpty) {
        _representadosPorEquipo.remove(anterior.equipoId);
      }
    }
    _ubicacion.remove(jugadorId);
  }

  /// Recalcula el titular de cada rol del equipo. Se hace solo para el equipo
  /// afectado, no para todo el mundo.
  void _reindexarTitulares(String? equipoId) {
    if (equipoId == null) return;
    final mapa = _titularesPorEquipoRol.putIfAbsent(
      equipoId,
      () => <String, Jugador>{},
    );
    mapa.clear();
    for (final jugador in _porEquipo[equipoId] ?? const <Jugador>[]) {
      if (jugador.suplente) continue;
      final actual = mapa[jugador.rol];
      if (actual == null || jugador.habilidad > actual.habilidad) {
        mapa[jugador.rol] = jugador;
      }
    }
    if (mapa.isEmpty) _titularesPorEquipoRol.remove(equipoId);
  }

  /// Elige el titular más débil de un equipo usando el índice de titulares.
  Jugador? titularMasDebilDe(String equipoId) {
    Jugador? debil;
    for (final jugador
        in _titularesPorEquipoRol[equipoId]?.values ?? const <Jugador>[]) {
      if (debil == null || jugador.habilidad < debil.habilidad) {
        debil = jugador;
      }
    }
    return debil;
  }

  /// Número de jugadores del índice (para pruebas e informes).
  int get cantidadJugadores => _jugadores.length;

  /// Número de representados con equipo (para pruebas e informes).
  int get cantidadRepresentadosConEquipo => _representadosPorEquipo.values
      .fold<int>(0, (total, lista) => total + lista.length);

  /// Compatibilidad con el código anterior que calculaba el máximo id.
  int calcularSiguienteId(Iterable<Jugador> jugadores) {
    var siguiente = 0;
    for (final jugador in jugadores) {
      if (!jugador.id.startsWith('p')) continue;
      final numero = int.tryParse(jugador.id.substring(1));
      if (numero != null) siguiente = max(siguiente, numero + 1);
    }
    return siguiente;
  }
}
