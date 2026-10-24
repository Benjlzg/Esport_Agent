// Satisfacción y contratos de representación (Parte 3B).
//
// El jugador valora si su agente le cumple las expectativas que tenía al
// firmar. Cada semana la satisfacción sube si todo se cumple y baja por cada
// expectativa incumplida. Si cae demasiado, el jugador pide hablar, acepta
// promesas o bonos y, en el peor caso, renuncia y se marcha con un rival.
import 'dart:math';

import '../modelos/agente_rival.dart';
import '../modelos/equipo.dart';
import '../modelos/estado_partida.dart';
import '../modelos/jugador.dart';
import '../modelos/noticia.dart';
import 'agentes_rivales.dart';
import 'formulas.dart';

// ------------------- EXPECTATIVAS -------------------

/// Claves de las expectativas. Se guardan como texto en `Jugador.expectativas`.
const String expectativaTenerEquipo = 'tenerEquipo';
const String expectativaSerTitular = 'serTitular';
const String expectativaPrimeraDivision = 'primeraDivision';
const String expectativaCobrarLoQueVale = 'cobrarLoQueVale';
const String expectativaEquipoPrestigioAlto = 'equipoPrestigioAlto';

/// Porcentaje del salario de mercado que el jugador considera aceptable.
const double porcentajeSalarioAceptable = 0.90;

/// Prestigio mínimo de un equipo de 1ª División para considerarlo de élite.
const int prestigioEquipoAlto = 80;

/// Edad máxima para esperar un ascenso desde la 2ª División.
const int edadMaximaPrimeraDivision = 24;

/// Habilidad mínima para la expectativa de cobrar lo que vale.
const int habilidadMinimaCobrarLoQueVale = 65;

/// Habilidad mínima para recibir `cobrarLoQueVale` como segunda expectativa.
const int habilidadMinimaSegundaExpectativa = 55;

/// Número máximo de expectativas que puede tener un jugador.
const int maxExpectativas = 2;

/// Devuelve la etiqueta visible de una expectativa.
String etiquetaExpectativa(String clave) {
  switch (clave) {
    case expectativaTenerEquipo:
      return 'Tener equipo';
    case expectativaSerTitular:
      return 'Ser titular';
    case expectativaPrimeraDivision:
      return 'Jugar en 1ª División';
    case expectativaCobrarLoQueVale:
      return 'Cobrar lo que vale';
    case expectativaEquipoPrestigioAlto:
      return 'Equipo de prestigio ≥ 80';
  }
  return clave;
}

/// Busca el equipo actual de un jugador (null si no tiene).
Equipo? equipoDe(EstadoPartida estado, Jugador jugador) {
  final id = jugador.equipoId;
  if (id == null) return null;
  for (final equipo in estado.equipos) {
    if (equipo.id == id) return equipo;
  }
  return null;
}

/// Genera entre una y dos expectativas según la situación del jugador.
List<String> generarExpectativas({required Jugador jugador, Equipo? equipo}) {
  final expectativas = <String>[];

  void agregar(String clave) {
    if (expectativas.length >= maxExpectativas) return;
    if (expectativas.contains(clave)) return;
    expectativas.add(clave);
  }

  if (jugador.equipoId == null) {
    agregar(expectativaTenerEquipo);
  } else {
    if (jugador.suplente) agregar(expectativaSerTitular);
    if (equipo != null &&
        equipo.division == 2 &&
        jugador.edad <= edadMaximaPrimeraDivision) {
      agregar(expectativaPrimeraDivision);
    }
    if (jugador.habilidad >= habilidadMinimaCobrarLoQueVale) {
      agregar(expectativaCobrarLoQueVale);
    }
    if (equipo != null &&
        equipo.division == 1 &&
        equipo.prestigio >= prestigioEquipoAlto) {
      agregar(expectativaEquipoPrestigioAlto);
    }
  }

  if (expectativas.length < maxExpectativas) {
    if (jugador.habilidad >= habilidadMinimaSegundaExpectativa) {
      agregar(expectativaCobrarLoQueVale);
    } else if (jugador.equipoId != null) {
      agregar(expectativaSerTitular);
    }
  }

  return expectativas;
}

/// true si una expectativa concreta se cumple ahora mismo.
bool expectativaCumplida({
  required Jugador jugador,
  required String clave,
  Equipo? equipo,
}) {
  switch (clave) {
    case expectativaTenerEquipo:
      return jugador.equipoId != null;
    case expectativaSerTitular:
      return jugador.equipoId != null && !jugador.suplente;
    case expectativaPrimeraDivision:
      return equipo != null && equipo.division == 1;
    case expectativaEquipoPrestigioAlto:
      return equipo != null &&
          equipo.division == 1 &&
          equipo.prestigio >= prestigioEquipoAlto;
    case expectativaCobrarLoQueVale:
      if (jugador.equipoId == null) return false;
      final salarioMercado = calcularSalarioAnual(valorMercadoDe(jugador));
      return jugador.salarioAnual >=
          salarioMercado * porcentajeSalarioAceptable;
  }
  return false;
}

/// Expectativas del jugador que ahora mismo no se cumplen.
List<String> expectativasIncumplidas({
  required Jugador jugador,
  Equipo? equipo,
}) {
  return jugador.expectativas
      .where(
        (clave) => !expectativaCumplida(
          jugador: jugador,
          clave: clave,
          equipo: equipo,
        ),
      )
      .toList();
}

// ------------------- SATISFACCIÓN SEMANAL -------------------

/// Subida semanal cuando todas las expectativas se cumplen.
const double deltaSatisfaccionSemanalCumplida = 0.5;

/// Castigo semanal por cada expectativa incumplida.
const double deltaSatisfaccionSemanalIncumplida = 1.5;

/// Castigo adicional mientras el jugador quiere hablar contigo.
const double penalizacionSemanalQuiereHablar = 2;

/// Satisfacción por debajo de la cual el jugador quiere hablar.
const int satisfaccionAlerta = 45;

/// Satisfacción por debajo de la cual puede renunciar.
const int satisfaccionCritica = 25;

/// Probabilidad semanal de renuncia con satisfacción crítica.
const double probRenunciaSemanal = 0.25;

/// Variación semanal de satisfacción. Positiva si todo se cumple.
double deltaSatisfaccionSemanal({
  required int incumplidas,
  bool quiereHablar = false,
}) {
  var delta = incumplidas == 0
      ? deltaSatisfaccionSemanalCumplida
      : -deltaSatisfaccionSemanalIncumplida * incumplidas;
  if (quiereHablar) delta -= penalizacionSemanalQuiereHablar;
  return delta;
}

/// Aplica una variación y mantiene la satisfacción entre 0 y 100.
int aplicarSatisfaccion(Jugador jugador, num delta) {
  jugador.satisfaccion = (jugador.satisfaccion + delta).round().clamp(0, 100);
  return jugador.satisfaccion;
}

// ------------------- PROMESAS, BONOS Y CHARLAS -------------------

/// Satisfacción inmediata al prometer una mejora.
const int promesaSatisfaccion = 10;

/// Semanas que se vigila una promesa antes de evaluarla.
const int semanasPromesaPendiente = 13;

/// Castigo si al vencer la promesa las expectativas siguen incumplidas.
const int castigoPromesaIncumplida = 20;

/// Recompensa si al vencer la promesa se cumplió lo prometido.
const int premioPromesaCumplida = 5;

/// Satisfacción que da pagar un bono.
const int bonoSatisfaccion = 15;

/// Porcentaje del valor de mercado que cuesta el bono.
const double porcentajeBonoApaciguar = 0.05;

/// Costo de apaciguar a un jugador con un bono.
int costoBonoApaciguar(Jugador jugador) {
  final valor = jugador.valorMercado > 0
      ? jugador.valorMercado
      : valorMercadoDe(jugador);
  return (valor * porcentajeBonoApaciguar).round();
}

/// Satisfacción que se pierde al ignorar al jugador.
const int castigoIgnorarJugador = 10;

// ------------------- CONTRATO DE REPRESENTACIÓN -------------------

/// Semanas del contrato de representación al reclutar.
const int contratoRepresentacionInicial = 52;

/// Comisión inicial del contrato (5 % del salario).
const double comisionSalarioContratoInicial = 0.05;

/// Límites de la comisión negociable.
const double comisionRepresentacionMin = 0.03;
const double comisionRepresentacionMax = 0.10;

/// Solo se puede renegociar cuando quedan estas semanas o menos.
const int umbralSemanasRenovacionRepresentacion = 8;

/// Duración mínima de una renovación de representación.
const int duracionMinimaRenovacionRepresentacion = 26;

/// Duración máxima de una renovación de representación.
const int duracionMaximaRenovacionRepresentacion = 104;

/// Comisión máxima que aceptaría el jugador para una duración concreta.
double comisionMaximaAceptable({
  required int satisfaccion,
  required int duracionSemanas,
}) {
  var base = (0.05 + (satisfaccion - 60) / 2000).clamp(
    comisionRepresentacionMin,
    0.08,
  );
  if (duracionSemanas >= 78) base -= 0.01;
  return base.toDouble();
}

/// true si el jugador acepta la comisión y duración ofrecidas.
bool aceptaRenovacionRepresentacion({
  required int satisfaccion,
  required double comisionOfrecida,
  required int duracionSemanas,
}) {
  if (duracionSemanas < duracionMinimaRenovacionRepresentacion) return false;
  if (duracionSemanas > duracionMaximaRenovacionRepresentacion) return false;
  if (comisionOfrecida < comisionRepresentacionMin - 1e-9) return false;
  if (comisionOfrecida > comisionRepresentacionMax + 1e-9) return false;
  final maxima = comisionMaximaAceptable(
    satisfaccion: satisfaccion,
    duracionSemanas: duracionSemanas,
  );
  return comisionOfrecida <= maxima + 1e-9;
}

/// Formatea una comisión como porcentaje visible: 0.05 -> "5 %".
String formatearComision(double fraccion) {
  final porcentaje = fraccion * 100;
  final texto = porcentaje == porcentaje.roundToDouble()
      ? porcentaje.round().toString()
      : porcentaje.toStringAsFixed(1);
  return '$texto %';
}

// ------------------- EFECTOS DE EVENTOS -------------------

/// Efecto de un traspaso según el prestigio del equipo anterior y el nuevo.
const int umbralDiferenciaPrestigio = 10;
const int efectoTraspasoPeorEquipo = -15;
const int efectoTraspasoMejorEquipo = 10;

/// Efecto de una renovación con más o menos salario.
const int efectoRenovacionSatisfaccion = 10;

/// Castigo por pasar todo un split como suplente.
const int efectoSuplenteSplitSatisfaccion = 8;

/// Satisfacción por ganar un título de liga o de mitad.
const int efectoTituloSatisfaccion = 10;

/// Satisfacción extra por ganar el Mundial.
const int efectoMundialSatisfaccion = 15;

/// Aplica el efecto de un traspaso a la satisfacción del jugador.
int aplicarEfectoSatisfaccionTraspaso({
  required Jugador jugador,
  required int prestigioAnterior,
  required int prestigioNuevo,
}) {
  if (prestigioNuevo < prestigioAnterior - umbralDiferenciaPrestigio) {
    return aplicarSatisfaccion(jugador, efectoTraspasoPeorEquipo);
  }
  if (prestigioNuevo > prestigioAnterior + umbralDiferenciaPrestigio) {
    return aplicarSatisfaccion(jugador, efectoTraspasoMejorEquipo);
  }
  return jugador.satisfaccion;
}

/// Aplica el efecto de una renovación de contrato con el club.
int aplicarEfectoSatisfaccionRenovacion({
  required Jugador jugador,
  required int salarioAnterior,
  required int salarioNuevo,
}) {
  if (salarioNuevo < salarioAnterior) {
    return aplicarSatisfaccion(jugador, -efectoRenovacionSatisfaccion);
  }
  if (salarioNuevo > salarioAnterior) {
    return aplicarSatisfaccion(jugador, efectoRenovacionSatisfaccion);
  }
  return jugador.satisfaccion;
}

/// Castiga al jugador que pasó todo un split en el banquillo.
int aplicarEfectoSuplenteSplit(Jugador jugador) =>
    aplicarSatisfaccion(jugador, -efectoSuplenteSplitSatisfaccion);

/// Premia al jugador que gana un título.
int aplicarEfectoTitulo(Jugador jugador, {required bool mundial}) =>
    (aplicarSatisfaccion(
      jugador,
      mundial ? efectoMundialSatisfaccion : efectoTituloSatisfaccion,
    ));

// ------------------- ASEGURAR DATOS -------------------

/// Completa las expectativas y el contrato de un representado. Se usa al
/// reclutar, al convencer a un jugador y al migrar partidas antiguas.
void asegurarExpectativasYContrato(Jugador jugador, {Equipo? equipo}) {
  if (!jugador.representadoPorMi) return;
  if (jugador.enAcademia) return;
  if (jugador.expectativas.isEmpty) {
    jugador.expectativas = generarExpectativas(
      jugador: jugador,
      equipo: equipo,
    );
  }
  if (jugador.comisionSalarioContrato < comisionRepresentacionMin ||
      jugador.comisionSalarioContrato > comisionRepresentacionMax) {
    jugador.comisionSalarioContrato = comisionSalarioContratoInicial;
  }
  if (jugador.semanasContratoRepresentacion < 0) {
    jugador.semanasContratoRepresentacion = 0;
  }
}

/// Genera expectativas a todos mis representados y garantiza su contrato.
void asegurarRepresentados(EstadoPartida estado) {
  for (final jugador in estado.jugadores) {
    if (!jugador.representadoPorMi) continue;
    asegurarExpectativasYContrato(jugador, equipo: equipoDe(estado, jugador));
  }
}

// ------------------- SEMANA DE UN REPRESENTADO -------------------

/// Resultado de procesar una semana de satisfacción y contrato.
class ResultadoSemanaSatisfaccion {
  ResultadoSemanaSatisfaccion();

  final List<Noticia> noticias = [];

  bool renuncio = false;
  bool contratoVencido = false;
  bool promesaCumplida = false;
  bool promesaIncumplida = false;
}

/// Procesa una semana completa de un jugador representado por mí:
/// promesa pendiente, variación de satisfacción, aviso de charla, contrato y
/// posible renuncia. Devuelve las noticias que el motor debe registrar.
ResultadoSemanaSatisfaccion procesarSemanaRepresentado({
  required EstadoPartida estado,
  required Jugador jugador,
  required Random rnd,
}) {
  final resultado = ResultadoSemanaSatisfaccion();
  if (!jugador.representadoPorMi) return resultado;
  if (jugador.enAcademia) return resultado;

  final equipo = equipoDe(estado, jugador);

  // 1) Promesa pendiente: al vencer se comprueba si se cumplió.
  if (jugador.semanasPromesaPendiente > 0) {
    jugador.semanasPromesaPendiente--;
    if (jugador.semanasPromesaPendiente == 0) {
      final incumplidas = expectativasIncumplidas(
        jugador: jugador,
        equipo: equipo,
      );
      if (incumplidas.isEmpty) {
        aplicarSatisfaccion(jugador, premioPromesaCumplida);
        resultado.promesaCumplida = true;
        resultado.noticias.add(
          Noticia(
            semana: estado.semana,
            temporada: estado.temporada,
            texto:
                '${jugador.nick} está contento: cumpliste la promesa que le '
                'hiciste.',
            tipo: TipoNoticia.evento,
          ),
        );
      } else {
        aplicarSatisfaccion(jugador, -castigoPromesaIncumplida);
        resultado.promesaIncumplida = true;
        resultado.noticias.add(
          Noticia(
            semana: estado.semana,
            temporada: estado.temporada,
            texto:
                '${jugador.nick} recuerda tu promesa incumplida y pierde '
                'confianza en ti.',
            tipo: TipoNoticia.alerta,
          ),
        );
      }
    }
  }

  // 2) Variación semanal por expectativas y por querer hablar.
  if (jugador.expectativas.isEmpty) {
    jugador.expectativas = generarExpectativas(
      jugador: jugador,
      equipo: equipo,
    );
  }
  final incumplidas = expectativasIncumplidas(jugador: jugador, equipo: equipo);
  final quiereHablarAntes = jugador.quiereHablar;
  aplicarSatisfaccion(
    jugador,
    deltaSatisfaccionSemanal(
      incumplidas: incumplidas.length,
      quiereHablar: quiereHablarAntes,
    ),
  );

  // 3) El aviso se activa al bajar de 45. Una promesa pendiente lo silencia
  // hasta que venza o el jugador vuelva a estar por debajo del umbral.
  if (jugador.semanasPromesaPendiente > 0) {
    jugador.quiereHablar = false;
  } else {
    jugador.quiereHablar = jugador.satisfaccion < satisfaccionAlerta;
  }

  // 4) Contrato de representación: baja una semana y puede expirar.
  if (jugador.semanasContratoRepresentacion > 0) {
    jugador.semanasContratoRepresentacion--;
  }
  if (jugador.semanasContratoRepresentacion <= 0) {
    _salirDeAgencia(jugador);
    resultado.contratoVencido = true;
    resultado.noticias.add(
      Noticia(
        semana: estado.semana,
        temporada: estado.temporada,
        texto:
            'El contrato de representación de ${jugador.nick} expiró y ahora '
            'está sin agente.',
        tipo: TipoNoticia.alerta,
      ),
    );
    return resultado;
  }

  // 5) Renuncia si la satisfacción es crítica.
  if (jugador.satisfaccion >= satisfaccionCritica) return resultado;
  if (rnd.nextDouble() >= probRenunciaSemanal) return resultado;

  final rival = _rivalQueLoAcepta(estado, jugador, rnd);
  _salirDeAgencia(jugador, agenteId: rival?.id);
  resultado.renuncio = true;
  if (rival != null) {
    resultado.noticias.add(
      Noticia(
        semana: estado.semana,
        temporada: estado.temporada,
        texto:
            '${jugador.nick} deja tu agencia por insatisfacción y firma con '
            '${rival.nombre}.',
        tipo: TipoNoticia.alerta,
      ),
    );
  } else {
    resultado.noticias.add(
      Noticia(
        semana: estado.semana,
        temporada: estado.temporada,
        texto:
            '${jugador.nick} deja tu agencia por insatisfacción y queda sin '
            'agente.',
        tipo: TipoNoticia.alerta,
      ),
    );
  }
  return resultado;
}

/// Deja al jugador fuera de mi agencia y limpia el contrato y los avisos.
void _salirDeAgencia(Jugador jugador, {String? agenteId}) {
  jugador.representadoPorMi = false;
  jugador.agenteId = agenteId;
  jugador.semanasRepresentado = 0;
  jugador.expectativas = [];
  jugador.quiereHablar = false;
  jugador.semanasPromesaPendiente = 0;
  jugador.semanasContratoRepresentacion = 0;
  jugador.comisionSalarioContrato = comisionSalarioContratoInicial;
  jugador.semanasEnfriamientoAgente = semanasEnfriamientoCambioAgente;
  jugador.semanasEsperaConvencer = 0;
}

/// Rival dispuesto a aceptar al jugador, o null si ninguno puede.
AgenteRival? _rivalQueLoAcepta(
  EstadoPartida estado,
  Jugador jugador,
  Random rnd,
) {
  final candidatos = estado.agentesRivales.where((rival) {
    if (rival.dinero < 0) return false;
    if (!aceptaRepresentacion(
      reputacion: rival.reputacion,
      habilidad: jugador.habilidad,
    )) {
      return false;
    }
    final maximo = maxCarteraPorPerfil[rival.perfil]!;
    return carteraDeRival(estado, rival).length < maximo;
  }).toList();
  if (candidatos.isEmpty) return null;
  return candidatos[rnd.nextInt(candidatos.length)];
}
