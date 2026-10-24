// Lógica de la academia de jóvenes (Parte 3E).
//
// La academia es una cantera propia: los candidatos solo se ven en su pantalla,
// se reclutan por $500, ocupan una de las 4 plazas y cuestan $150 por semana.
// Mientras entrenan no cuentan como representados normales: no pagan comisión,
// no tienen expectativas ni satisfacción, no pueden ser robados y la IA no los
// considera. Al colocarlos en 2ª División, el equipo paga su valor de mercado
// y la agencia cobra los derechos de formación.
import 'dart:math';

import '../modelos/equipo.dart';
import '../modelos/estado_partida.dart';
import '../modelos/juego.dart';
import '../modelos/jugador.dart';
import '../modelos/noticia.dart';
import 'calendario.dart';
import 'generador_jugadores.dart';
import 'ojeadores.dart';

// ------------------- CONSTANTES DE BALANCE -------------------

/// Plazas disponibles en la academia.
const int capacidadAcademia = 4;

/// Costo de fichar a un candidato para la academia.
const int costoFichajeAcademia = 500;

/// Costo semanal de mantener a cada joven en la academia.
const int costoSemanalAcademiaPorJoven = 150;

/// Candidatos que se generan al empezar cada temporada (2 por videojuego).
const int jovenesAcademiaPorTemporada = 8;

/// Edad de los candidatos que se generan.
const int edadAcademiaMin = 15;
const int edadAcademiaMax = 17;

/// Requisitos para colocar a un joven en un equipo de 2ª División. La
/// habilidad mínima subió de 45 a 50 en el balance final de la 3E.
const int edadMinimaColocacion = 17;
const int semanasEntrenamientoMinimo = 4;
const int habilidadMinimaColocar = 50;

/// Bonus de progresión mientras el joven entrena en la academia.
const double bonusProgresionAcademia = 1.5;

/// Porcentaje del valor de mercado que la agencia cobra como derechos de
/// formación. Es una constante ajustable: el balance final de la 3E la bajó
/// por rondas (1,0 → 0,6 → 0,4) para que la academia no dominara los ingresos.
const double porcentajeDerechosFormacion = 0.4;

/// Edad a la que un joven sin colocar puede marcharse por su cuenta.
const int edadSalidaAcademia = 18;

/// Probabilidad semanal de que un joven de 18 o más se marche sin colocar.
const double probSalidaAcademiaSemanal = 0.20;

// ------------------- CONSULTAS -------------------

/// Jóvenes que están entrenando ahora mismo en la academia.
List<Jugador> jovenesEnAcademia(EstadoPartida estado) =>
    estado.jugadores.where((j) => j.enAcademia).toList();

/// Candidatos que todavía no han sido reclutados por la academia.
List<Jugador> candidatosDeAcademia(EstadoPartida estado) => estado.jugadores
    .where((j) => j.candidatoAcademia && !j.enAcademia)
    .toList();

/// Gasto semanal de mantener a todos los jóvenes de la academia.
int gastoSemanalAcademia(EstadoPartida estado) =>
    jovenesEnAcademia(estado).length * costoSemanalAcademiaPorJoven;

/// Plazas libres que quedan en la academia.
int plazasLibresAcademia(EstadoPartida estado) =>
    max(0, capacidadAcademia - jovenesEnAcademia(estado).length);

/// true si el mercado está en una ventana en la que se puede colocar.
bool ventanaDeColocacionAbierta(EstadoPartida estado) =>
    enVentanaFichajes(estado.semana);

/// Reglas físicas de colocación: edad, entrenamiento y habilidad. La ventana
/// se comprueba aparte porque un joven puede estar listo con el mercado cerrado.
bool cumpleRequisitosColocacion(Jugador jugador) {
  if (!jugador.enAcademia) return false;
  if (jugador.edad < edadMinimaColocacion) return false;
  if (jugador.semanasEnAcademia < semanasEntrenamientoMinimo) return false;
  if (jugador.habilidad < habilidadMinimaColocar) return false;
  return true;
}

/// Motivos legibles por los que no se puede colocar ahora mismo. La lista
/// vacía significa que la operación es válida.
List<String> motivosParaColocar(EstadoPartida estado, Jugador jugador) {
  final motivos = <String>[];
  if (!jugador.enAcademia) {
    motivos.add('${jugador.nick} no está en la academia.');
    return motivos;
  }
  if (jugador.edad < edadMinimaColocacion) {
    motivos.add(
      'Debe tener al menos $edadMinimaColocacion años. '
      'Tiene ${jugador.edad}.',
    );
  }
  if (jugador.semanasEnAcademia < semanasEntrenamientoMinimo) {
    final faltan = semanasEntrenamientoMinimo - jugador.semanasEnAcademia;
    motivos.add(
      'Debe entrenar $semanasEntrenamientoMinimo semanas. '
      'Le faltan $faltan.',
    );
  }
  if (jugador.habilidad < habilidadMinimaColocar) {
    motivos.add(
      'Necesita al menos $habilidadMinimaColocar de habilidad. '
      'Tiene ${jugador.habilidad}.',
    );
  }
  if (!ventanaDeColocacionAbierta(estado)) {
    motivos.add(
      'El mercado está cerrado. ${proximaVentanaTexto(estado.semana)}',
    );
  }
  if (cumpleRequisitosColocacion(jugador) &&
      ventanaDeColocacionAbierta(estado) &&
      equiposParaColocar(estado, jugador).isEmpty) {
    motivos.add(
      'Ningún equipo de 2ª División puede pagar su valor de mercado.',
    );
  }
  return motivos;
}

/// Equipos de 2ª División del mismo videojuego que pueden pagar el valor de
/// mercado completo del joven. Se ordenan por prestigio para mostrar primero
/// los destinos más atractivos.
List<Equipo> equiposParaColocar(EstadoPartida estado, Jugador jugador) {
  if (!jugador.enAcademia) return const [];
  final valor = jugador.valorMercado;
  final equipos =
      estado.equipos
          .where(
            (e) =>
                e.division == 2 &&
                e.juego == jugador.juego &&
                e.presupuesto >= valor &&
                e.id != jugador.equipoId,
          )
          .toList()
        ..sort((a, b) {
          final porPrestigio = b.prestigio.compareTo(a.prestigio);
          if (porPrestigio != 0) return porPrestigio;
          return a.nombre.compareTo(b.nombre);
        });
  return equipos;
}

/// Jóvenes que ya cumplen los requisitos físicos para ser colocados. No exige
/// que la ventana esté abierta: la pantalla avisa de que el mercado está
/// cerrado cuando corresponde.
List<Jugador> jovenesListosParaColocar(EstadoPartida estado) =>
    jovenesEnAcademia(estado).where(cumpleRequisitosColocacion).toList();

/// Estrecha el rango de potencial de un joven por sus semanas de entrenamiento.
///
/// A diferencia de los ojeadores, la academia reduce el semiancho con
/// `floor(semanasEnAcademia / 2)` aunque no haya ningún ojeador. El rango
/// nunca se reabre: se conserva la intersección con el que ya conocía el
/// jugador.
void observarPotencialAcademia(Jugador jugador) {
  mantenerRangoPotencial(jugador);
  final minimoAnterior = jugador.potencialVisibleMin;
  final maximoAnterior = jugador.potencialVisibleMax;
  if (minimoAnterior == null || maximoAnterior == null) return;
  if (minimoAnterior >= maximoAnterior) return;

  final nuevo = rangoPotencialVisible(
    jugador: jugador,
    nivelMejor: 0,
    semanasObservado: jugador.semanasEnAcademia,
  );
  jugador.potencialVisibleMin = max(minimoAnterior, nuevo.min);
  jugador.potencialVisibleMax = min(maximoAnterior, nuevo.max);
  mantenerRangoPotencial(jugador);
}

// ------------------- GENERACIÓN -------------------

/// Genera los 8 candidatos de la temporada y los añade al estado.
///
/// Se generan 2 por videojuego. La región se elige entre las que tienen
/// equipos de ese juego para que los ojeadores puedan cubrirlos con la regla
/// de juego+región de la Parte 3C.
List<Jugador> generarCandidatosAcademia(
  EstadoPartida estado,
  Random rnd,
  String Function() nuevoId,
) {
  final regionesPorJuego = <Juego, List<String>>{};
  for (final equipo in estado.equipos) {
    final regiones = regionesPorJuego.putIfAbsent(
      equipo.juego,
      () => <String>[],
    );
    if (!regiones.contains(equipo.region)) regiones.add(equipo.region);
  }

  final nicksUsados = estado.jugadores.map((j) => j.nick).toSet();
  final nuevos = <Jugador>[];
  for (final juego in Juego.values) {
    final regiones = List<String>.from(
      regionesPorJuego[juego] ?? const <String>[],
    )..shuffle(rnd);
    for (
      var i = 0;
      i < jovenesAcademiaPorTemporada ~/ Juego.values.length;
      i++
    ) {
      final region = regiones.isEmpty ? null : regiones[i % regiones.length];
      final joven = generarCandidatoAcademia(
        rnd,
        id: nuevoId(),
        juego: juego,
        region: region,
        nicksUsados: nicksUsados,
      );
      nuevos.add(joven);
      estado.jugadores.add(joven);
    }
  }
  return nuevos;
}

/// Destapa a los candidatos que nadie reclutó al terminar la temporada.
/// Pasan a ser jugadores sin equipo normales, sin agente.
int destaparCandidatos(EstadoPartida estado) {
  var destapados = 0;
  for (final jugador in estado.jugadores) {
    if (!jugador.candidatoAcademia) continue;
    jugador.candidatoAcademia = false;
    destapados++;
  }
  return destapados;
}

/// Libera a un joven de la academia y lo deja como agente libre.
void liberarJovenDeAcademia(Jugador jugador) {
  jugador.enAcademia = false;
  jugador.semanasEnAcademia = 0;
  jugador.candidatoAcademia = false;
  jugador.representadoPorMi = false;
  jugador.agenteId = null;
  jugador.equipoId = null;
  jugador.sueldoDeAcademiaLimpiar();
}

/// Corrige los campos de academia al cargar una partida. No gasta RNG y no
/// crea candidatos: una partida v13 los recibirá al empezar la próxima
/// temporada, tal como pide la migración.
void normalizarAcademia(EstadoPartida estado) {
  for (final jugador in estado.jugadores) {
    if (jugador.semanasEnAcademia < 0) jugador.semanasEnAcademia = 0;
    if (jugador.enAcademia && jugador.candidatoAcademia) {
      jugador.candidatoAcademia = false;
    }
    if (jugador.enAcademia) {
      jugador.representadoPorMi = true;
      jugador.agenteId = 'yo';
      jugador.expectativas = [];
      jugador.quiereHablar = false;
      jugador.semanasPromesaPendiente = 0;
      if (jugador.equipoId != null) {
        jugador.equipoId = null;
        jugador.semanasContrato = 0;
        jugador.suplente = false;
        jugador.semanasComoSuplente = 0;
      }
    } else if (jugador.candidatoAcademia) {
      jugador.representadoPorMi = false;
      jugador.agenteId = null;
      jugador.equipoId = null;
      jugador.semanasContrato = 0;
      jugador.semanasEnAcademia = 0;
    }
  }
}

// ------------------- SEMANA -------------------

/// Resultado de procesar la academia en una semana.
class ResultadoSemanaAcademia {
  ResultadoSemanaAcademia();

  final List<Noticia> noticias = [];

  /// Jóvenes que se marcharon por su cuenta al cumplir 18 sin colocación.
  int salidas = 0;
}

/// Procesa una semana de un único joven de la academia.
///
/// Devuelve la noticia si se marchó por su cuenta, o null si sigue entrenando.
/// Se llama desde el recorrido único por jugador de `TemporadaService`.
Noticia? procesarSemanaJovenAcademia(
  EstadoPartida estado,
  Jugador jugador,
  Random rnd,
) {
  if (!jugador.enAcademia) return null;
  jugador.semanasEnAcademia++;
  observarPotencialAcademia(jugador);

  if (jugador.edad < edadSalidaAcademia) return null;
  if (rnd.nextDouble() >= probSalidaAcademiaSemanal) return null;

  liberarJovenDeAcademia(jugador);
  return Noticia(
    semana: estado.semana,
    temporada: estado.temporada,
    texto:
        '${jugador.nick} deja la academia a los ${jugador.edad} años y '
        'queda como agente libre.',
    tipo: TipoNoticia.alerta,
  );
}

/// Procesa el entrenamiento y la posible salida de los jóvenes de la academia.
///
/// Se usa en pruebas y utilidades que no tienen el recorrido semanal completo.
/// En el juego real, `TemporadaService` llama a
/// [procesarSemanaJovenAcademia] dentro de su único bucle por jugador (R1).
ResultadoSemanaAcademia procesarSemanaAcademia(
  EstadoPartida estado,
  Random rnd,
) {
  final resultado = ResultadoSemanaAcademia();
  for (final jugador in estado.jugadores) {
    if (!jugador.enAcademia) continue;
    final noticia = procesarSemanaJovenAcademia(estado, jugador, rnd);
    if (noticia == null) continue;
    resultado.salidas++;
    resultado.noticias.add(noticia);
  }
  return resultado;
}

/// Método auxiliar de [liberarJovenDeAcademia].
///
/// Se define como extensión para que la limpieza de los campos de contrato de
/// representación quede en un único lugar y no se olvide ningún campo.
extension LimpiezaAcademia on Jugador {
  void sueldoDeAcademiaLimpiar() {
    expectativas = [];
    quiereHablar = false;
    semanasPromesaPendiente = 0;
    semanasContratoRepresentacion = 0;
    comisionSalarioContrato = 0.05;
    semanasRepresentado = 0;
    semanasEnfriamientoAgente = 0;
    semanasEsperaConvencer = 0;
    satisfaccion = 70;
    semanasContrato = 0;
    semanasComoSuplente = 0;
    suplente = false;
  }
}
