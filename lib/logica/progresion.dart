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
double probabilidadProgresoSemanal(Jugador jugador) {
  var probabilidad = probabilidadProgresoJovenPorEdad(jugador.edad);
  if (jugador.equipoId == null) {
    probabilidad *= factorProgresoSinEquipo;
  } else if (jugador.suplente) {
    probabilidad *= factorProgresoSuplente;
  }
  if (jugador.moral > moralAltaProgreso) {
    probabilidad *= factorProgresoMoralAlta;
  }
  return probabilidad;
}

/// Puntos que sube un joven cuando acierta la tirada semanal.
int subidaProgresoSemanal(Random rnd, int edad) {
  if (edad <= edadMaximaSubidaDoble) return 1 + rnd.nextInt(2);
  return 1;
}

/// Aplica la progresión de una semana a [jugador] y devuelve cuántos puntos
/// cambió su habilidad (positivo si subió, negativo si bajó, 0 si no cambió).
///
/// Se mantiene una tirada por jugador y semana, igual que antes, para no
/// alterar el orden general de los números aleatorios de la simulación.
int aplicarProgresoSemanal(Jugador jugador, Random rnd) {
  final dado = rnd.nextDouble();

  if (jugador.edad <= edadMaximaProgresoJoven) {
    if (jugador.habilidad >= jugador.potencial) return 0;
    final probabilidad = probabilidadProgresoSemanal(jugador);
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
    // Adultos: 15 % de subir o bajar 1 (no suben si la moral es muy baja).
    if (dado < 0.15) {
      final subir = rnd.nextBool();
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

  // Mayores: 20 % de bajar 1.
  if (dado < 0.20) {
    final antes = jugador.habilidad;
    jugador.habilidad = max(1, jugador.habilidad - 1);
    return jugador.habilidad - antes;
  }
  return 0;
}
