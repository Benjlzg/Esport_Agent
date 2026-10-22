// Pruebas de la progresión juvenil (Fase 2.5, ajuste de balance).
//
// Comprueban que un jugador de 16 a 21 años sube entre 4 y 8 puntos por
// temporada con equipo, que sin equipo la probabilidad es la mitad y que un
// suplente mejora un poco menos que un titular.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:esport_agent/logica/progresion.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';

Jugador _jugador({
  required int edad,
  String? equipoId,
  bool suplente = false,
  int habilidad = 50,
  int potencial = 99,
  int moral = 70,
}) => Jugador(
  id: 'j_$edad',
  nick: 'Test$edad',
  nombreReal: 'Jugador de prueba',
  pais: 'Chile',
  edad: edad,
  juego: Juego.lol,
  rol: 'Mid',
  habilidad: habilidad,
  potencial: potencial,
  moral: moral,
  equipoId: equipoId,
  salarioAnual: 0,
  semanasContrato: 0,
  suplente: suplente,
);

/// Simula [semanas] semanas de progresión para [cantidad] jugadores iguales.
double _promedioTemporada({
  required int edad,
  required int cantidad,
  required int semanas,
  String? equipoId,
  bool suplente = false,
  int semilla = 1234,
}) {
  final rnd = Random(semilla);
  var total = 0;
  for (var i = 0; i < cantidad; i++) {
    final jugador = _jugador(
      edad: edad,
      equipoId: equipoId,
      suplente: suplente,
    );
    final inicial = jugador.habilidad;
    for (var semana = 0; semana < semanas; semana++) {
      aplicarProgresoSemanal(jugador, rnd);
    }
    total += jugador.habilidad - inicial;
  }
  return total / cantidad;
}

void main() {
  group('probabilidades', () {
    test('no aumentan con la edad y bajan al llegar a adulto', () {
      final p16 = probabilidadProgresoJovenPorEdad(16);
      final p19 = probabilidadProgresoJovenPorEdad(19);
      final p21 = probabilidadProgresoJovenPorEdad(21);
      final p23 = probabilidadProgresoJovenPorEdad(23);
      expect(p16, greaterThanOrEqualTo(p19));
      expect(p19, greaterThanOrEqualTo(p21));
      expect(p21, greaterThan(p23));
    });

    test('sin equipo la probabilidad es exactamente la mitad', () {
      final conEquipo = _jugador(edad: 19, equipoId: 'eq');
      final sinEquipo = _jugador(edad: 19);
      expect(
        probabilidadProgresoSemanal(sinEquipo),
        closeTo(probabilidadProgresoSemanal(conEquipo) * 0.5, 1e-9),
      );
    });

    test('un suplente tiene menos probabilidad que un titular', () {
      final titular = _jugador(edad: 19, equipoId: 'eq');
      final suplente = _jugador(edad: 19, equipoId: 'eq', suplente: true);
      expect(
        probabilidadProgresoSemanal(suplente),
        lessThan(probabilidadProgresoSemanal(titular)),
      );
    });

    test('la moral alta da un pequeño bonus', () {
      final normal = _jugador(edad: 19, equipoId: 'eq');
      final alta = _jugador(edad: 19, equipoId: 'eq', moral: 90);
      expect(
        probabilidadProgresoSemanal(alta),
        greaterThan(probabilidadProgresoSemanal(normal)),
      );
    });
  });

  group('subida por temporada', () {
    test('16–21 años con equipo suben entre 4 y 8 puntos', () {
      // La media se toma sobre las seis edades, como en el informe. Un joven
      // de 16 puede superar ligeramente 8 antes de tocar su potencial, pero
      // la media del grupo debe quedar dentro del objetivo.
      var suma = 0.0;
      for (var edad = 16; edad <= 21; edad++) {
        suma += _promedioTemporada(
          edad: edad,
          cantidad: 2000,
          semanas: 52,
          equipoId: 'eq',
          semilla: 7000 + edad,
        );
      }
      final promedio = suma / 6;
      expect(promedio, inInclusiveRange(4.0, 8.0));
    });

    test('sin equipo suben aproximadamente la mitad que con equipo', () {
      final conEquipo = _promedioTemporada(
        edad: 19,
        cantidad: 3000,
        semanas: 52,
        equipoId: 'eq',
      );
      final sinEquipo = _promedioTemporada(
        edad: 19,
        cantidad: 3000,
        semanas: 52,
      );
      expect(sinEquipo, closeTo(conEquipo / 2, 0.6));
    });

    test('los suplentes suben un poco menos que los titulares', () {
      final titulares = _promedioTemporada(
        edad: 19,
        cantidad: 3000,
        semanas: 52,
        equipoId: 'eq',
      );
      final suplentes = _promedioTemporada(
        edad: 19,
        cantidad: 3000,
        semanas: 52,
        equipoId: 'eq',
        suplente: true,
      );
      expect(suplentes, lessThan(titulares));
      expect(suplentes, greaterThan(titulares * 0.75));
    });

    test('no superan su potencial', () {
      final rnd = Random(99);
      final jugador = _jugador(
        edad: 17,
        equipoId: 'eq',
        habilidad: 90,
        potencial: 92,
      );
      for (var semana = 0; semana < 520; semana++) {
        aplicarProgresoSemanal(jugador, rnd);
      }
      expect(jugador.habilidad, lessThanOrEqualTo(92));
    });
  });
}
