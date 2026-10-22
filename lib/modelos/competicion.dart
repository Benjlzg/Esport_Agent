// Modelo de una liga: un videojuego, una región y una división.
// Guarda todos los resultados de la temporada; de ahí se derivan la tabla
// de posiciones, la forma de los equipos y el historial directo.
import '../logica/formulas.dart';
import 'juego.dart';
import 'partido.dart';

/// Una fila de la tabla de posiciones (datos derivados, no se guardan).
class FilaTabla {
  FilaTabla({required this.equipoId});

  final String equipoId;
  int jugados = 0;
  int ganados = 0;
  int perdidos = 0;
  int mapasG = 0;
  int mapasP = 0;

  /// Puntos de liga (victoria = 3).
  int get puntos => ganados * puntosVictoria;

  /// Diferencia de mapas (desempate).
  int get diferenciaMapas => mapasG - mapasP;
}

/// Una competición (liga) de un videojuego, región y división.
class Competicion {
  Competicion({
    required this.juego,
    required this.region,
    required this.division,
    required this.liga,
    required this.equipoIds,
    List<ResultadoSerie>? resultadosSplit1,
    List<ResultadoSerie>? resultadosSplit2,
    List<ResultadoSerie>? resultadosPlayoffs1,
    List<ResultadoSerie>? resultadosPlayoffs2,
  }) : resultadosSplit1 = resultadosSplit1 ?? <ResultadoSerie>[],
       resultadosSplit2 = resultadosSplit2 ?? <ResultadoSerie>[],
       resultadosPlayoffs1 = resultadosPlayoffs1 ?? <ResultadoSerie>[],
       resultadosPlayoffs2 = resultadosPlayoffs2 ?? <ResultadoSerie>[];

  /// Videojuego de la liga.
  final Juego juego;

  /// Región de la liga.
  final String region;

  /// División (1 o 2).
  final int division;

  /// Nombre de la liga.
  final String liga;

  /// Ids de los equipos en orden estable (base del calendario).
  final List<String> equipoIds;

  /// Resultados de la fase regular de cada split.
  final List<ResultadoSerie> resultadosSplit1;
  final List<ResultadoSerie> resultadosSplit2;

  /// Resultados de los playoffs de cada split.
  final List<ResultadoSerie> resultadosPlayoffs1;
  final List<ResultadoSerie> resultadosPlayoffs2;

  /// Identificador textual único de la liga.
  String get identificador => '${juego.name}_${region}_$division';

  /// Nombre completo para mostrar (ej: "LoL · Corea · 1ª División").
  String get nombreCompleto => '${juego.corto} · $region · $divisionª División';

  // ------------------- ACCESO A RESULTADOS -------------------

  /// Resultados de la fase regular de un split.
  List<ResultadoSerie> resultadosDeSplit(int split) =>
      split == 1 ? resultadosSplit1 : resultadosSplit2;

  /// Resultados de playoffs de un split.
  List<ResultadoSerie> resultadosPlayoffsDe(int split) =>
      split == 1 ? resultadosPlayoffs1 : resultadosPlayoffs2;

  /// Todos los resultados de la temporada, en orden cronológico.
  List<ResultadoSerie> get todosLosResultados => [
    ...resultadosSplit1,
    ...resultadosPlayoffs1,
    ...resultadosSplit2,
    ...resultadosPlayoffs2,
  ];

  /// Agrega resultados a la fase regular de un split.
  void agregarResultados(int split, List<ResultadoSerie> nuevos) {
    resultadosDeSplit(split).addAll(nuevos);
  }

  /// Agrega resultados a los playoffs de un split.
  void agregarPlayoffs(int split, List<ResultadoSerie> nuevos) {
    resultadosPlayoffsDe(split).addAll(nuevos);
  }

  // ------------------- DERIVADOS -------------------

  /// Tabla de posiciones de un split, ordenada.
  List<FilaTabla> tablaSplit(int split) {
    final filas = <String, FilaTabla>{
      for (final id in equipoIds) id: FilaTabla(equipoId: id),
    };
    for (final r in resultadosDeSplit(split)) {
      final local = filas[r.localId];
      final visitante = filas[r.visitanteId];
      if (local == null || visitante == null) continue;
      _sumar(local, visitante, r);
    }
    final lista = filas.values.toList()
      ..sort((a, b) {
        final porPuntos = b.puntos.compareTo(a.puntos);
        if (porPuntos != 0) return porPuntos;
        final porMapas = b.diferenciaMapas.compareTo(a.diferenciaMapas);
        if (porMapas != 0) return porMapas;
        return b.mapasG.compareTo(a.mapasG);
      });
    return lista;
  }

  void _sumar(FilaTabla local, FilaTabla visitante, ResultadoSerie r) {
    local.jugados++;
    visitante.jugados++;
    if (r.ganadorId == local.equipoId) {
      local.ganados++;
      visitante.perdidos++;
    } else {
      visitante.ganados++;
      local.perdidos++;
    }
    local.mapasG += r.mapasLocal;
    local.mapasP += r.mapasVisitante;
    visitante.mapasG += r.mapasVisitante;
    visitante.mapasP += r.mapasLocal;
  }

  /// Campeón de los playoffs de un split (null mientras no se juegue la
  /// final: hacen falta las 2 semifinales y la final, 3 resultados).
  String? campeonSplit(int split) {
    final playoffs = resultadosPlayoffsDe(split);
    if (playoffs.length < 3) return null;
    return playoffs.last.ganadorId;
  }

  /// Últimos resultados (V/D) de un equipo, el más reciente primero.
  /// `todosLosResultados` ya viene en orden cronológico.
  List<String> formaEquipo(String equipoId) {
    final jugados = todosLosResultados
        .where((r) => r.participa(equipoId))
        .toList();
    return jugados.reversed
        .take(partidosForma)
        .map((r) => r.gano(equipoId) ? 'V' : 'D')
        .toList();
  }

  /// Victorias seguidas actuales de un equipo.
  int rachaGanadora(String equipoId) {
    final jugados = todosLosResultados
        .where((r) => r.participa(equipoId))
        .toList();
    var racha = 0;
    for (final r in jugados.reversed) {
      if (r.gano(equipoId)) {
        racha++;
      } else {
        break;
      }
    }
    return racha;
  }

  /// Historial directo del año entre dos equipos.
  List<ResultadoSerie> enfrentamientos(String a, String b) => todosLosResultados
      .where((r) => r.participa(a) && r.participa(b))
      .toList();

  /// Vacía todos los resultados (para empezar una temporada nueva).
  void reiniciar() {
    resultadosSplit1.clear();
    resultadosSplit2.clear();
    resultadosPlayoffs1.clear();
    resultadosPlayoffs2.clear();
  }

  // ------------------- SERIALIZACIÓN -------------------

  Map<String, dynamic> toJson() {
    return {
      'juego': juego.name,
      'region': region,
      'division': division,
      'liga': liga,
      'equipoIds': equipoIds,
      'resultadosSplit1': resultadosSplit1.map((r) => r.toJson()).toList(),
      'resultadosSplit2': resultadosSplit2.map((r) => r.toJson()).toList(),
      'resultadosPlayoffs1': resultadosPlayoffs1
          .map((r) => r.toJson())
          .toList(),
      'resultadosPlayoffs2': resultadosPlayoffs2
          .map((r) => r.toJson())
          .toList(),
    };
  }

  factory Competicion.fromJson(Map<String, dynamic> json) {
    List<ResultadoSerie> leer(String clave) =>
        ((json[clave] as List?) ?? const [])
            .map((e) => ResultadoSerie.fromJson(e as Map<String, dynamic>))
            .toList();
    return Competicion(
      juego: Juego.porNombre(json['juego'] as String),
      region: json['region'] as String,
      division: (json['division'] as num).toInt(),
      liga: json['liga'] as String,
      equipoIds: ((json['equipoIds'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      resultadosSplit1: leer('resultadosSplit1'),
      resultadosSplit2: leer('resultadosSplit2'),
      resultadosPlayoffs1: leer('resultadosPlayoffs1'),
      resultadosPlayoffs2: leer('resultadosPlayoffs2'),
    );
  }
}
