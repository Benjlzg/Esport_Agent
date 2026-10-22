// Apoyo común para las simulaciones largas (Fase 2.5): partida sembrada,
// prefs simuladas, resolución automática de eventos y formato Markdown.
import 'package:esport_agent/logica/formulas.dart';
import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/historial.dart';
import 'package:esport_agent/modelos/juego.dart';

/// Semilla fija usada en los informes de balance.
const int semillaInforme = 20251019;

/// Dinero del agente observador: evita bancarrotas artificiales por la oficina.
const int dineroObservador = 1000000000;

/// Crea una partida nueva con la semilla del informe. El mundo se carga desde
/// los assets reales del proyecto, igual que en la app.
Future<MotorJuego> crearPartidaSembrada({
  int semilla = semillaInforme,
  int dinero = dineroObservador,
  int reputacion = reputacionInicial,
}) async {
  final motor = MotorJuego(semilla: semilla);
  await motor.nuevaPartida(nombre: 'Observador', pais: 'Chile');
  motor.agente.dinero = dinero;
  motor.agente.reputacion = reputacion;
  return motor;
}

/// Resuelve todos los eventos pendientes eligiendo la opción más barata.
/// Los informativos se cierran con la opción A.
Future<void> resolverEventosAutomaticos(MotorJuego motor) async {
  while (motor.eventosPendientes.isNotEmpty) {
    final evento = motor.eventosPendientes.first;
    var opcion = 0;
    if (evento.esDecision) {
      opcion = evento.costoBaseB < evento.costoBaseA ? 1 : 0;
    }
    await motor.resolverEvento(evento, opcion);
  }
}

/// Avanza una semana y resuelve sus eventos, como haría el jugador.
Future<void> avanzarSemanaSimulada(MotorJuego motor) async {
  await motor.avanzarSemana();
  await resolverEventosAutomaticos(motor);
}

/// Suma el presupuesto de todos los equipos.
int presupuestoTotal(EstadoPartida estado) =>
    estado.equipos.fold(0, (suma, equipo) => suma + equipo.presupuesto);

/// Promedio de habilidad de los jugadores con equipo (plantillas activas).
double habilidadPromedioPorJuego(EstadoPartida estado, Juego juego) {
  final jugadores = estado.jugadores
      .where((j) => j.juego == juego && j.equipoId != null)
      .toList();
  if (jugadores.isEmpty) return 0;
  final suma = jugadores.fold<int>(0, (total, j) => total + j.habilidad);
  return suma / jugadores.length;
}

/// Dominio de un equipo en una liga de 1ª División (corrección 2.5 B3).
class DominioLiga {
  DominioLiga({
    required this.liga,
    required this.equipoId,
    required this.temporadasGanadas,
    required this.titulosSplit,
  });

  /// Nombre completo de la liga (videojuego, región y división).
  final String liga;

  /// Equipo que más veces ganó esta liga.
  final String equipoId;

  /// Temporadas distintas en las que ganó al menos un split (de 10).
  final int temporadasGanadas;

  /// Títulos de split ganados en total (2 por temporada como máximo).
  final int titulosSplit;
}

/// Para cada liga de 1ª División, el equipo que más temporadas ganó.
///
/// Se cuentan temporadas distintas con al menos un split ganado, no el total
/// de títulos: así el criterio "más de 6 de 10 temporadas" se lee directo.
/// El resultado viene ordenado de mayor a menor dominio.
List<DominioLiga> dominioPorLiga(EstadoPartida estado) {
  final resultado = <DominioLiga>[];
  for (final comp in estado.competiciones.where((c) => c.division == 1)) {
    final temporadasPorEquipo = <String, Set<int>>{};
    final titulosPorEquipo = <String, int>{};
    for (final titulo in estado.palmares) {
      if (titulo.tipo != TipoCampeon.liga) continue;
      if (titulo.juego != comp.juego) continue;
      // La descripción de un título de liga es "<liga> (Split N)". Se exige
      // el paréntesis para no confundir la 1ª con la 2ª División.
      if (!titulo.descripcion.startsWith('${comp.liga} (Split')) continue;
      temporadasPorEquipo
          .putIfAbsent(titulo.ganadorId, () => <int>{})
          .add(titulo.temporada);
      titulosPorEquipo[titulo.ganadorId] =
          (titulosPorEquipo[titulo.ganadorId] ?? 0) + 1;
    }
    if (temporadasPorEquipo.isEmpty) continue;

    var mejorId = temporadasPorEquipo.keys.first;
    for (final entrada in temporadasPorEquipo.entries) {
      final mejorActual = temporadasPorEquipo[mejorId]!.length;
      if (entrada.value.length > mejorActual ||
          (entrada.value.length == mejorActual &&
              (titulosPorEquipo[entrada.key] ?? 0) >
                  (titulosPorEquipo[mejorId] ?? 0))) {
        mejorId = entrada.key;
      }
    }
    resultado.add(
      DominioLiga(
        liga: '${comp.liga} · ${comp.juego.corto} · ${comp.region}',
        equipoId: mejorId,
        temporadasGanadas: temporadasPorEquipo[mejorId]!.length,
        titulosSplit: titulosPorEquipo[mejorId] ?? 0,
      ),
    );
  }
  resultado.sort((a, b) {
    final porTemporadas = b.temporadasGanadas.compareTo(a.temporadasGanadas);
    if (porTemporadas != 0) return porTemporadas;
    final porTitulos = b.titulosSplit.compareTo(a.titulosSplit);
    if (porTitulos != 0) return porTitulos;
    return a.liga.compareTo(b.liga);
  });
  return resultado;
}

/// Formatea un entero con separador de miles simple (sin locale).
String miles(int valor) {
  final texto = valor.abs().toString();
  final partes = <String>[];
  for (var i = texto.length; i > 0; i -= 3) {
    final inicio = i - 3 < 0 ? 0 : i - 3;
    partes.insert(0, texto.substring(inicio, i));
  }
  final signo = valor < 0 ? '-' : '';
  return '$signo${partes.join('.')}';
}

/// Formatea un decimal con [decimales] posiciones.
String decimal(num valor, [int decimales = 2]) =>
    valor.toStringAsFixed(decimales);

/// Construye una tabla Markdown.
String tablaMarkdown(List<String> encabezados, List<List<String>> filas) {
  final buffer = StringBuffer()
    ..writeln('| ${encabezados.join(' | ')} |')
    ..writeln('| ${encabezados.map((_) => '---').join(' | ')} |');
  for (final fila in filas) {
    buffer.writeln('| ${fila.join(' | ')} |');
  }
  return buffer.toString();
}

/// Una constante de balance ajustada durante la fase.
class AjusteBalance {
  const AjusteBalance({
    required this.constante,
    required this.antes,
    required this.despues,
    required this.motivo,
    required this.ronda,
  });

  final String constante;
  final String antes;
  final String despues;
  final String motivo;
  final int ronda;
}
