// Modelo de un jugador profesional de esports.
import 'juego.dart';

/// Representa a un jugador. Muchos campos cambian durante la partida
/// (habilidad, moral, equipo, contrato...), por eso no son "final".
class Jugador {
  Jugador({
    required this.id,
    required this.nick,
    required this.nombreReal,
    required this.pais,
    required this.edad,
    required this.juego,
    required this.rol,
    required this.habilidad,
    required this.potencial,
    this.moral = 70,
    this.equipoId,
    required this.salarioAnual,
    required this.semanasContrato,
    this.representadoPorMi = false,
    this.esReal = false,
    this.suplente = false,
    this.region,
    this.semanasComoSuplente = 0,
    this.semanasInactivo = 0,
    this.semanasRepresentado = 0,
    this.temporadaUltimoTraspaso,
    this.partidasTemporada = 0,
    this.victoriasTemporada = 0,
    this.notaTotalTemporada = 0,
    this.eliminacionesTemporada = 0,
    this.muertesTemporada = 0,
    this.asistenciasTemporada = 0,
    this.mvpsTemporada = 0,
    this.eliminacionesCarrera = 0,
    this.muertesCarrera = 0,
    this.asistenciasCarrera = 0,
    this.mvpsCarrera = 0,
    this.multiplicadorValor = 1.0,
    List<double>? ultimasNotas,
  }) : ultimasNotas = ultimasNotas ?? <double>[];

  /// Identificador único (ej: "lol_0001").
  final String id;

  /// Nombre de jugador (ej: "Faker").
  String nick;

  /// Nombre real de la persona.
  String nombreReal;

  /// País de origen (texto, ej: "Corea del Sur").
  String pais;

  /// Edad, de 16 a 35.
  int edad;

  /// Videojuego en el que compite.
  Juego juego;

  /// Rol dentro del juego (ej: "Mid").
  String rol;

  /// Nivel actual, de 1 a 100.
  int habilidad;

  /// Nivel máximo posible, de 1 a 100 (siempre mayor o igual que la habilidad).
  int potencial;

  /// Estado de ánimo, de 0 a 100 (empieza en 70).
  int moral;

  /// Equipo actual (null = agente libre).
  String? equipoId;

  /// Salario anual en dólares.
  int salarioAnual;

  /// Semanas de contrato que le quedan.
  int semanasContrato;

  /// true si forma parte de mi agencia (yo lo represento).
  bool representadoPorMi;

  /// true = jugador real, false = generado por el juego.
  bool esReal;

  /// true = está en el banquillo (suplente) de su equipo. Los suplentes no
  /// juegan ni cuentan para el poder del equipo.
  bool suplente;

  /// Región de origen del jugador (null en partidas antiguas o jugadores sin
  /// región asignada). Se usa para generar/libre jóvenes de cada región.
  String? region;

  /// Semanas seguidas que lleva como suplente dentro de un split. Sirve para
  /// aplicar el castigo de moral al terminar el split (Parte 2D).
  int semanasComoSuplente;

  /// Semanas que el jugador estará inactivo (lesión o descanso). Mientras sea
  /// mayor que 0 no juega ni cuenta para el poder de su equipo (Parte 2E).
  int semanasInactivo;

  /// true si el jugador no puede jugar esta semana por lesión o descanso.
  bool get estaInactivo => semanasInactivo > 0;

  /// Semanas que llevas representando a este jugador. Se reinicia a 0 al
  /// dejarlo o al volver a reclutarlo y sube cada semana en el motor. El
  /// periodo mínimo para ofrecerlo a un equipo vive en `formulas.dart`
  /// (corrección I1 de la auditoría).
  int semanasRepresentado;

  /// Temporada en la que el jugador cambió de equipo por última vez. Sirve
  /// para que un fichaje reciente no pueda volver a venderse en la misma
  /// temporada (corrección 2.5 A2). Es null en partidas antiguas.
  int? temporadaUltimoTraspaso;

  /// true si el jugador acaba de cambiar de equipo y debe esperar a la
  /// próxima temporada para volver a negociar un traspaso.
  bool bloqueadoTraspaso(int temporadaActual) =>
      temporadaUltimoTraspaso != null &&
      temporadaUltimoTraspaso! >= temporadaActual;

  /// Partidos jugados esta temporada.
  int partidasTemporada;

  /// Partidos ganados esta temporada.
  int victoriasTemporada;

  /// Suma de las notas de la temporada (para sacar el promedio).
  double notaTotalTemporada;

  /// Eliminaciones, muertes y asistencias de esta temporada.
  int eliminacionesTemporada;
  int muertesTemporada;
  int asistenciasTemporada;

  /// Veces que fue MVP de la serie esta temporada.
  int mvpsTemporada;

  /// Estadísticas acumuladas de toda la carrera.
  int eliminacionesCarrera;
  int muertesCarrera;
  int asistenciasCarrera;
  int mvpsCarrera;

  /// Multiplicador del valor de mercado (sube o baja según la forma).
  double multiplicadorValor;

  /// Últimas notas (máximo 5), usadas para calcular la forma.
  List<double> ultimasNotas;

  /// Valor de mercado actual del jugador. Se recalcula con las fórmulas.
  /// No se guarda: se calcula al cargar la partida.
  int valorMercado = 0;

  /// Nota promedio de la temporada (0 si aún no jugó partidos).
  double get promedioNota =>
      partidasTemporada == 0 ? 0 : notaTotalTemporada / partidasTemporada;

  /// Derrotas de la temporada.
  int get derrotasTemporada => partidasTemporada - victoriasTemporada;

  /// KDA de la temporada: (eliminaciones + asistencias) / muertes.
  double get kdaTemporada =>
      (eliminacionesTemporada + asistenciasTemporada) /
      (muertesTemporada < 1 ? 1 : muertesTemporada);

  /// KDA de toda la carrera.
  double get kdaCarrera =>
      (eliminacionesCarrera + asistenciasCarrera) /
      (muertesCarrera < 1 ? 1 : muertesCarrera);

  /// Convierte el jugador a un mapa para guardarlo en JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nick': nick,
      'nombreReal': nombreReal,
      'pais': pais,
      'edad': edad,
      'juego': juego.name,
      'rol': rol,
      'habilidad': habilidad,
      'potencial': potencial,
      'moral': moral,
      'equipoId': equipoId,
      'salarioAnual': salarioAnual,
      'semanasContrato': semanasContrato,
      'representadoPorMi': representadoPorMi,
      'esReal': esReal,
      'suplente': suplente,
      'region': region,
      'semanasComoSuplente': semanasComoSuplente,
      'semanasInactivo': semanasInactivo,
      'semanasRepresentado': semanasRepresentado,
      'temporadaUltimoTraspaso': temporadaUltimoTraspaso,
      'partidasTemporada': partidasTemporada,
      'victoriasTemporada': victoriasTemporada,
      'notaTotalTemporada': notaTotalTemporada,
      'eliminacionesTemporada': eliminacionesTemporada,
      'muertesTemporada': muertesTemporada,
      'asistenciasTemporada': asistenciasTemporada,
      'mvpsTemporada': mvpsTemporada,
      'eliminacionesCarrera': eliminacionesCarrera,
      'muertesCarrera': muertesCarrera,
      'asistenciasCarrera': asistenciasCarrera,
      'mvpsCarrera': mvpsCarrera,
      'multiplicadorValor': multiplicadorValor,
      'ultimasNotas': ultimasNotas,
    };
  }

  /// Reconstruye un jugador desde un mapa JSON guardado.
  factory Jugador.fromJson(Map<String, dynamic> json) {
    return Jugador(
      id: json['id'] as String,
      nick: json['nick'] as String,
      nombreReal: json['nombreReal'] as String,
      pais: json['pais'] as String,
      edad: json['edad'] as int,
      juego: Juego.porNombre(json['juego'] as String),
      rol: json['rol'] as String,
      habilidad: json['habilidad'] as int,
      potencial: json['potencial'] as int,
      moral: json['moral'] as int,
      equipoId: json['equipoId'] as String?,
      salarioAnual: json['salarioAnual'] as int,
      semanasContrato: json['semanasContrato'] as int,
      representadoPorMi: json['representadoPorMi'] as bool,
      esReal: json['esReal'] as bool,
      suplente: json['suplente'] as bool? ?? false,
      region: json['region'] as String?,
      semanasComoSuplente: (json['semanasComoSuplente'] as num?)?.toInt() ?? 0,
      semanasInactivo: (json['semanasInactivo'] as num?)?.toInt() ?? 0,
      semanasRepresentado: (json['semanasRepresentado'] as num?)?.toInt() ?? 0,
      temporadaUltimoTraspaso: (json['temporadaUltimoTraspaso'] as num?)
          ?.toInt(),
      partidasTemporada: (json['partidasTemporada'] as num?)?.toInt() ?? 0,
      victoriasTemporada: (json['victoriasTemporada'] as num?)?.toInt() ?? 0,
      notaTotalTemporada: (json['notaTotalTemporada'] as num?)?.toDouble() ?? 0,
      eliminacionesTemporada:
          (json['eliminacionesTemporada'] as num?)?.toInt() ?? 0,
      muertesTemporada: (json['muertesTemporada'] as num?)?.toInt() ?? 0,
      asistenciasTemporada:
          (json['asistenciasTemporada'] as num?)?.toInt() ?? 0,
      mvpsTemporada: (json['mvpsTemporada'] as num?)?.toInt() ?? 0,
      eliminacionesCarrera:
          (json['eliminacionesCarrera'] as num?)?.toInt() ?? 0,
      muertesCarrera: (json['muertesCarrera'] as num?)?.toInt() ?? 0,
      asistenciasCarrera: (json['asistenciasCarrera'] as num?)?.toInt() ?? 0,
      mvpsCarrera: (json['mvpsCarrera'] as num?)?.toInt() ?? 0,
      multiplicadorValor:
          (json['multiplicadorValor'] as num?)?.toDouble() ?? 1.0,
      ultimasNotas:
          (json['ultimasNotas'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          <double>[],
    );
  }
}
