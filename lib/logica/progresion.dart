// Progresión semanal de la habilidad de los jugadores.
//
// Antes todos los jóvenes (≤ 23) tenían un 30 % semanal de subir 1 o 2 puntos.
// Eso hacía que un jugador de 19 años pudiera pasar de 72 a 94 en una sola
// temporada. Ahora la probabilidad baja con la edad y depende de si el jugador
// tiene equipo y de si es titular o suplente.
import 'dart:math';

import '../modelos/jugador.dart';

/// Edad máxima que sigue la progresión juvenil rápida.
const int edadMaximaProgresoJoven = 23;

/// Hasta esta edad la subida puede ser de 1 o 2 puntos; después, de 1.
const int edadMaximaSubidaDoble = 21;

/// Edad máxima de la progresión de adultos (sube o baja 1).
const int edadMaximaProgresoAdulto = 27;

/// Moral mínima para que un joven pueda mejorar.
const int moralMinimaProgresoJoven = 30;

/// Moral alta: pequeño bonus de progresión.
const int moralAltaProgreso = 80;
const double factorProgresoMoralAlta = 1.10;

/// Tope del multiplicador externo de progresión (preparador de la Parte 3D).
const double topeMultiplicadorProgreso = 1.4;

/// Sin equipo la probabilidad de mejorar se reduce a la mitad.
const double factorProgresoSinEquipo = 0.5;

/// Un suplente mejora un poco menos que un titular.
const double factorProgresoSuplente = 0.85;

/// Probabilidad semanal base de mejorar según la edad.
///
/// Con una subida media de 1,5 puntos y 52 semanas, los valores dan:
/// - 16–17 años: ≈ 7,8 puntos por temporada.
/// - 18–19 años: ≈ 7,8 puntos por temporada.
/// - 20–21 años: ≈ 7,0 puntos por temporada.
/// - 22–23 años: ≈ 2,6 puntos por temporada.
///
/// La subida real es menor porque muchos jóvenes llegan a su potencial antes
/// de terminar la temporada; por eso el informe mide a quienes todavía tienen
/// margen de mejora. El objetivo es que la media real quede entre 4 y 8 y que
/// la habilidad promedio se estabilice rápido (salto ≤ 3 entre temporadas).
double probabilidadProgresoJovenPorEdad(int edad) {
  if (edad <= 17) return 0.10;
  if (edad <= 19) return 0.10;
  if (edad <= 21) return 0.09;
  return 0.05;
}

/// Probabilidad semanal real de que [jugador] mejore, aplicando los factores
/// de equipo, titularidad y moral.
///
/// [multiplicador] permite aplicar el bonus del preparador (Parte 3D). Siempre
/// se acota al tope [topeMultiplicadorProgreso] para que ningún efecto lo
/// apile por encima de ×1,4.
double probabilidadProgresoSemanal(
  Jugador jugador, {
  double multiplicador = 1.0,
}) {
  var probabilidad = probabilidadProgresoJovenPorEdad(jugador.edad);
  if (jugador.equipoId == null) {
    probabilidad *= factorProgresoSinEquipo;
  } else if (jugador.suplente) {
    probabilidad *= factorProgresoSuplente;
  }
  if (jugador.moral > moralAltaProgreso) {
    probabilidad *= factorProgresoMoralAlta;
  }
  final factor = multiplicador.clamp(1.0, topeMultiplicadorProgreso);
  return (probabilidad * factor).clamp(0.0, 1.0);
}

/// Puntos que sube un joven cuando acierta la tirada semanal.
int subidaProgresoSemanal(Random rnd, int edad) {
  if (edad <= edadMaximaSubidaDoble) return 1 + rnd.nextInt(2);
  return 1;
}

/// Aplica la progresión de una semana a [jugador] y devuelve cuántos puntos
/// cambió su habilidad (positivo si subió, negativo si bajó, 0 si no cambió).
///
/// [multiplicadorProbabilidad] es el bonus del preparador (Parte 3D). Solo se
/// aplica a la probabilidad de MEJORAR: en los jóvenes multiplica la tirada de
/// progresión y en los adultos (24–27) inclina la balanza hacia la mejora sin
/// aumentar los descensos. Los mayores de 28 solo tienen probabilidad de bajar,
/// así que no reciben este bonus.
///
/// Se mantiene una tirada por jugador y semana, igual que antes, para no
/// alterar el orden general de los números aleatorios de la simulación.
int aplicarProgresoSemanal(
  Jugador jugador,
  Random rnd, {
  double multiplicadorProbabilidad = 1.0,
}) {
  final multiplicador = multiplicadorProbabilidad.clamp(
    1.0,
    topeMultiplicadorProgreso,
  );
  final dado = rnd.nextDouble();

  if (jugador.edad <= edadMaximaProgresoJoven) {
    if (jugador.habilidad >= jugador.potencial) return 0;
    final probabilidad = probabilidadProgresoSemanal(
      jugador,
      multiplicador: multiplicador,
    );
    if (jugador.moral < moralMinimaProgresoJoven || dado >= probabilidad) {
      return 0;
    }
    final antes = jugador.habilidad;
    jugador.habilidad = min(
      jugador.potencial,
      jugador.habilidad + subidaProgresoSemanal(rnd, jugador.edad),
    );
    return jugador.habilidad - antes;
  }

  if (jugador.edad <= edadMaximaProgresoAdulto) {
    // Adultos: 15 % de cambiar 1 punto. La dirección era 50/50; el preparador
    // aumenta la parte de mejora y deja igual la de bajada. Los descensos no
    // se multiplican para que el staff nunca perjudique a mis representados.
    if (dado < 0.15) {
      final probabilidadSubir = (0.5 * multiplicador).clamp(0.0, 1.0);
      final subir = rnd.nextDouble() < probabilidadSubir;
      if (subir) {
        if (jugador.moral >= moralMinimaProgresoJoven) {
          final antes = jugador.habilidad;
          jugador.habilidad = min(jugador.potencial, jugador.habilidad + 1);
          return jugador.habilidad - antes;
        }
      } else {
        final antes = jugador.habilidad;
        jugador.habilidad = max(1, jugador.habilidad - 1);
        return jugador.habilidad - antes;
      }
    }
    return 0;
  }

  // Mayores: 20 % de bajar 1. No hay probabilidad de progresión que el
  // preparador pueda mejorar.
  if (dado < 0.20) {
    final antes = jugador.habilidad;
    jugador.habilidad = max(1, jugador.habilidad - 1);
    return jugador.habilidad - antes;
  }
  return 0;
}
