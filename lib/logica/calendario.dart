// Calendario de la temporada: qué etapa se juega en cada semana.
// Las semanas 1–4 son pretemporada, 5–18 el Split 1, 19–20 sus playoffs,
// 21–22 el torneo internacional, 23–26 la 2ª ventana de fichajes, 27–40 el
// Split 2, 41–42 sus playoffs, 43–46 el Mundial y 47–52 el cierre de
// temporada.

/// Tipo de etapa, útil para saber qué se simula en cada momento.
enum TipoEtapa {
  pretemporada,
  liga,
  playoffs,
  internacional,
  fichajes,
  mundial,
  finTemporada,
}

/// Una etapa del calendario, con el rango de semanas que ocupa.
class Etapa {
  const Etapa({
    required this.nombre,
    required this.detalle,
    required this.semanaInicio,
    required this.semanaFin,
    required this.tipo,
  });

  /// Nombre corto (ej: "Split 1 · Fecha 3").
  final String nombre;

  /// Descripción para la pantalla de calendario.
  final String detalle;

  /// Primera y última semana de la etapa.
  final int semanaInicio;
  final int semanaFin;

  /// Tipo de etapa.
  final TipoEtapa tipo;

  /// ¿La etapa contiene la semana indicada?
  bool contiene(int semana) => semana >= semanaInicio && semana <= semanaFin;
}

/// Devuelve la etapa concreta que se juega en una semana.
Etapa etapaDeSemana(int semana) {
  if (semana <= 4) {
    return const Etapa(
      nombre: 'Pretemporada · Ventana de fichajes 1',
      detalle: 'Preparación y fichajes antes del arranque.',
      semanaInicio: 1,
      semanaFin: 4,
      tipo: TipoEtapa.pretemporada,
    );
  }
  if (semana <= 18) {
    final fecha = semana - 4;
    return Etapa(
      nombre: 'Split 1 · Fecha $fecha',
      detalle: 'Fase regular del primer split.',
      semanaInicio: 5,
      semanaFin: 18,
      tipo: TipoEtapa.liga,
    );
  }
  if (semana <= 20) {
    return Etapa(
      nombre: 'Playoffs Split 1',
      detalle: 'Semifinales y final del primer split.',
      semanaInicio: 19,
      semanaFin: 20,
      tipo: TipoEtapa.playoffs,
    );
  }
  if (semana <= 22) {
    return const Etapa(
      nombre: 'Torneo Internacional',
      detalle: 'Torneo de mitad de temporada.',
      semanaInicio: 21,
      semanaFin: 22,
      tipo: TipoEtapa.internacional,
    );
  }
  if (semana <= 26) {
    return const Etapa(
      nombre: 'Ventana de fichajes 2',
      detalle: 'Mercado de mitad de temporada.',
      semanaInicio: 23,
      semanaFin: 26,
      tipo: TipoEtapa.fichajes,
    );
  }
  if (semana <= 40) {
    final fecha = semana - 26;
    return Etapa(
      nombre: 'Split 2 · Fecha $fecha',
      detalle: 'Fase regular del segundo split.',
      semanaInicio: 27,
      semanaFin: 40,
      tipo: TipoEtapa.liga,
    );
  }
  if (semana <= 42) {
    return Etapa(
      nombre: 'Playoffs Split 2',
      detalle: 'Semifinales y final del segundo split.',
      semanaInicio: 41,
      semanaFin: 42,
      tipo: TipoEtapa.playoffs,
    );
  }
  if (semana <= 46) {
    return const Etapa(
      nombre: 'Mundial',
      detalle: 'Torneo mundial de fin de temporada.',
      semanaInicio: 43,
      semanaFin: 46,
      tipo: TipoEtapa.mundial,
    );
  }
  return const Etapa(
    nombre: 'Fin de temporada',
    detalle: 'Cierre: premios y mercado.',
    semanaInicio: 47,
    semanaFin: 52,
    tipo: TipoEtapa.finTemporada,
  );
}

/// Lista de etapas de una temporada completa (para la pantalla Calendario).
List<Etapa> listaEtapas() => const [
  Etapa(
    nombre: 'Pretemporada · Ventana de fichajes 1',
    detalle: 'Preparación y fichajes antes del arranque.',
    semanaInicio: 1,
    semanaFin: 4,
    tipo: TipoEtapa.pretemporada,
  ),
  Etapa(
    nombre: 'Split 1 · Fase regular',
    detalle: '14 fechas con todos los equipos de la liga.',
    semanaInicio: 5,
    semanaFin: 18,
    tipo: TipoEtapa.liga,
  ),
  Etapa(
    nombre: 'Playoffs Split 1',
    detalle: 'Semifinales y final del primer split.',
    semanaInicio: 19,
    semanaFin: 20,
    tipo: TipoEtapa.playoffs,
  ),
  Etapa(
    nombre: 'Torneo Internacional',
    detalle: 'Torneo de mitad de temporada.',
    semanaInicio: 21,
    semanaFin: 22,
    tipo: TipoEtapa.internacional,
  ),
  Etapa(
    nombre: 'Ventana de fichajes 2',
    detalle: 'Mercado de mitad de temporada.',
    semanaInicio: 23,
    semanaFin: 26,
    tipo: TipoEtapa.fichajes,
  ),
  Etapa(
    nombre: 'Split 2 · Fase regular',
    detalle: '14 fechas con todos los equipos de la liga.',
    semanaInicio: 27,
    semanaFin: 40,
    tipo: TipoEtapa.liga,
  ),
  Etapa(
    nombre: 'Playoffs Split 2',
    detalle: 'Semifinales y final del segundo split.',
    semanaInicio: 41,
    semanaFin: 42,
    tipo: TipoEtapa.playoffs,
  ),
  Etapa(
    nombre: 'Mundial',
    detalle: 'Torneo mundial de fin de temporada.',
    semanaInicio: 43,
    semanaFin: 46,
    tipo: TipoEtapa.mundial,
  ),
  Etapa(
    nombre: 'Fin de temporada',
    detalle: 'Cierre: premios y mercado.',
    semanaInicio: 47,
    semanaFin: 52,
    tipo: TipoEtapa.finTemporada,
  ),
];

/// Split de liga que se juega en la semana (null si no hay fase regular).
int? splitDeLiga(int semana) {
  if (semana >= 5 && semana <= 18) return 1;
  if (semana >= 27 && semana <= 40) return 2;
  return null;
}

/// Número de fecha del split que se juega en la semana (1 a 14).
int? fechaDeLiga(int semana) {
  if (semana >= 5 && semana <= 18) return semana - 4;
  if (semana >= 27 && semana <= 40) return semana - 26;
  return null;
}

/// Split cuyos playoffs se juegan en la semana (null si no toca).
int? splitDePlayoffs(int semana) {
  if (semana >= 19 && semana <= 20) return 1;
  if (semana >= 41 && semana <= 42) return 2;
  return null;
}

/// Ronda de playoffs: 0 = semifinales, 1 = final.
int? rondaPlayoff(int semana) {
  if (semana == 19 || semana == 41) return 0;
  if (semana == 20 || semana == 42) return 1;
  return null;
}

/// ¿Estamos en una ventana de fichajes? (semanas 1–4, 23–26 y 47–52).
/// Solo los traspasos dependen de la ventana; las renovaciones se revisan
/// todas las semanas.
bool enVentanaFichajes(int semana) =>
    (semana >= 1 && semana <= 4) ||
    (semana >= 23 && semana <= 26) ||
    (semana >= 47 && semana <= 52);

/// Texto con la próxima ventana de fichajes. Si ya estamos dentro de una
/// ventana devuelve una cadena vacía.
String proximaVentanaTexto(int semana) {
  if (enVentanaFichajes(semana)) return '';
  if (semana < 1) return 'Próxima ventana: semana 1';
  if (semana <= 22) return 'Próxima ventana: semana 23';
  return 'Próxima ventana: semana 47';
}
