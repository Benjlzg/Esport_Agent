// Ascensos y descensos al cerrar la temporada (rollover 52 → 1).
//
// Por cada región y videojuego: baja el último de la 1ª División (tabla
// sumada de ambos splits) y sube el campeón del Split 2 de la 2ª División.
// Se ajusta la división, la liga, el prestigio (±8, con tope 1–100) y el
// presupuesto (prestigio × 20.000). Devuelve las noticias generadas.
import '../modelos/competicion.dart';
import '../modelos/equipo.dart';
import '../modelos/estado_partida.dart';
import 'formulas.dart';
import 'torneos.dart';

/// Procesa los ascensos y descensos de todas las regiones.
List<String> procesarAscensosYDescensos(EstadoPartida estado) {
  final noticias = <String>[];
  final equipos = <String, Equipo>{for (final e in estado.equipos) e.id: e};

  // Agrupo las competiciones por videojuego + región.
  final porJuegoRegion = <String, List<Competicion>>{};
  for (final comp in estado.competiciones) {
    porJuegoRegion
        .putIfAbsent('${comp.juego.name}|${comp.region}', () => [])
        .add(comp);
  }

  for (final grupo in porJuegoRegion.values) {
    final primera = _competicionDe(grupo, 1);
    final segunda = _competicionDe(grupo, 2);
    if (primera == null) continue;

    // Descenso: el último de la 1ª División por la tabla sumada.
    final tabla = tablaSumada(primera);
    if (tabla.isNotEmpty) {
      final descendido = equipos[tabla.last];
      if (descendido != null) {
        descendido.division = 2;
        if (segunda != null) descendido.liga = segunda.liga;
        _ajustarPrestigio(descendido, -prestigioAscensoDescenso);
        noticias.add(
          '${descendido.nombre} desciende a la 2ª División de ${primera.region}.',
        );
      }
    }

    // Ascenso: el campeón del Split 2 de la 2ª División.
    if (segunda != null) {
      final campeonId = segunda.campeonSplit(2);
      final ascendido = campeonId == null ? null : equipos[campeonId];
      if (ascendido != null) {
        ascendido.division = 1;
        ascendido.liga = primera.liga;
        _ajustarPrestigio(ascendido, prestigioAscensoDescenso);
        noticias.add(
          '${ascendido.nombre} asciende a la 1ª División de ${primera.region}.',
        );
      }
    }
  }

  return noticias;
}

/// Devuelve la competición de una división dentro de un grupo (o null).
Competicion? _competicionDe(List<Competicion> grupo, int division) {
  for (final comp in grupo) {
    if (comp.division == division) return comp;
  }
  return null;
}

/// Ajusta el prestigio dentro del rango 1–100 y recalcula el presupuesto.
void _ajustarPrestigio(Equipo equipo, int delta) {
  equipo.prestigio = (equipo.prestigio + delta).clamp(1, 100);
  equipo.presupuesto = equipo.prestigio * presupuestoPorPrestigio;
}
