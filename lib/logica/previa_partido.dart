// Modelo de la previa de un partido.
//
// Antes la pantalla calculaba el poder, la probabilidad, la forma, el
// historial y el duelo clave. Ahora todo se construye aquí para que la
// simulación y la interfaz no diverjan (sección 5 de la auditoría).
import '../modelos/competicion.dart';
import '../modelos/equipo.dart';
import '../modelos/jugador.dart';
import 'formulas.dart';
import 'simulador_partidos.dart';

/// Una entrada del historial directo, ya orientada a los dos equipos que se
/// muestran en la previa.
///
/// El resultado guarda quién fue local en su día; si fue el visitante de la
/// pantalla, los marcadores se intercambian (M3 de la auditoría).
class EntradaHistorialDirecto {
  const EntradaHistorialDirecto({
    required this.golesLocal,
    required this.golesVisitante,
    required this.etapa,
  });

  final int golesLocal;
  final int golesVisitante;
  final String etapa;
}

/// Duelo entre dos jugadores del mismo rol.
class DueloClave {
  const DueloClave({required this.local, required this.visitante});

  final Jugador local;
  final Jugador visitante;

  /// Rol que disputan (ambos tienen el mismo).
  String get rol => local.rol;

  /// Suma de habilidad, usada para elegir el duelo más atractivo.
  int get puntaje => local.habilidad + visitante.habilidad;
}

/// Todos los datos que necesita `PantallaPreviaPartido`.
class PreviaPartido {
  const PreviaPartido({
    required this.local,
    required this.visitante,
    required this.poderLocal,
    required this.poderVisitante,
    required this.probabilidadLocal,
    required this.formaLocal,
    required this.formaVisitante,
    required this.historial,
    required this.dueloClave,
  });

  final Equipo local;
  final Equipo visitante;
  final double poderLocal;
  final double poderVisitante;
  final double probabilidadLocal;
  final List<String> formaLocal;
  final List<String> formaVisitante;
  final List<EntradaHistorialDirecto> historial;
  final DueloClave? dueloClave;
}

/// Construye la previa de un partido entre [local] y [visitante].
PreviaPartido construirPreviaPartido({
  required Competicion competicion,
  required Equipo local,
  required Equipo visitante,
  required List<Jugador> jugadores,
}) {
  final poderLocal = poderEquipo(local, jugadores);
  final poderVisitante = poderEquipo(visitante, jugadores);
  final historial = competicion.enfrentamientos(local.id, visitante.id).map((
    resultado,
  ) {
    final localEraElLocal = resultado.localId == local.id;
    return EntradaHistorialDirecto(
      golesLocal: localEraElLocal
          ? resultado.mapasLocal
          : resultado.mapasVisitante,
      golesVisitante: localEraElLocal
          ? resultado.mapasVisitante
          : resultado.mapasLocal,
      etapa: resultado.etapa,
    );
  }).toList();

  return PreviaPartido(
    local: local,
    visitante: visitante,
    poderLocal: poderLocal,
    poderVisitante: poderVisitante,
    probabilidadLocal: probVictoria(poderLocal, poderVisitante),
    formaLocal: competicion.formaEquipo(local.id),
    formaVisitante: competicion.formaEquipo(visitante.id),
    historial: historial,
    dueloClave: _dueloClave(local, visitante, jugadores),
  );
}

/// Busca el duelo del mismo rol con más habilidad sumada.
DueloClave? _dueloClave(
  Equipo local,
  Equipo visitante,
  List<Jugador> jugadores,
) {
  final plantillaLocal = alineacionDe(local, jugadores);
  final plantillaVisitante = alineacionDe(visitante, jugadores);

  DueloClave? mejor;
  for (final a in plantillaLocal) {
    for (final b in plantillaVisitante) {
      if (a.rol != b.rol) continue;
      final candidato = DueloClave(local: a, visitante: b);
      if (mejor == null || candidato.puntaje > mejor.puntaje) {
        mejor = candidato;
      }
    }
  }
  return mejor;
}
