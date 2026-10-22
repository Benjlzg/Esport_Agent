// Pruebas rápidas de las reglas de balance de la Fase 2.5:
// ingresos de eventos, reputación por traspaso y paridad de equipos.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:esport_agent/logica/eventos.dart';
import 'package:esport_agent/logica/formulas.dart';
import 'package:esport_agent/logica/generador_equipos.dart';
import 'package:esport_agent/modelos/equipo.dart';
import 'package:esport_agent/modelos/juego.dart';

void main() {
  group('dominio y paridad', () {
    test('el divisor de probVictoria es más alto que el original', () {
      // Estaba en 6,0 y se subió para reducir el determinismo de las series.
      expect(factorProbabilidad, greaterThanOrEqualTo(15.0));
    });

    test('los equipos ficticios de 1ª tienen nivel competitivo', () {
      final rnd = Random(7);
      for (var i = 0; i < 40; i++) {
        final equipo = generarEquipoFicticio(
          rnd,
          id: 'fic_$i',
          juego: Juego.lol,
          region: 'Test',
          division: 1,
          liga: 'Liga Test',
        );
        expect(equipo.prestigio, inInclusiveRange(70, 80));
      }
    });

    test('los equipos ficticios de 2ª mantienen el rango histórico', () {
      final rnd = Random(7);
      for (var i = 0; i < 40; i++) {
        final equipo = generarEquipoFicticio(
          rnd,
          id: 'fic2_$i',
          juego: Juego.lol,
          region: 'Test',
          division: 2,
          liga: 'Liga Test - Segunda',
        );
        expect(equipo.prestigio, inInclusiveRange(35, 54));
      }
    });
  });

  group('ingresos de eventos', () {
    test('los eventos pagan menos que antes', () {
      expect(gananciaStreamerMax, lessThanOrEqualTo(6000));
      expect(gananciaMarcaMax, lessThanOrEqualTo(15000));
      expect(gananciaInversorMax, lessThanOrEqualTo(30000));
    });
  });

  group('reputación por traspaso', () {
    test('crece al principio y se frena al ser una agencia conocida', () {
      expect(
        reputacionPorTraspaso(reputacionActual: 10, elite: false),
        2,
      );
      expect(
        reputacionPorTraspaso(reputacionActual: 10, elite: true),
        3,
      );
      expect(
        reputacionPorTraspaso(reputacionActual: 30, elite: false),
        1,
      );
      expect(
        reputacionPorTraspaso(reputacionActual: 39, elite: true),
        2,
      );
      expect(
        reputacionPorTraspaso(reputacionActual: 40, elite: true),
        0,
      );
    });
  });

  group('desgaste competitivo', () {
    test('factorPoder tiene 1,0 por defecto y se guarda en el JSON', () {
      final equipo = Equipo(
        id: 'e1',
        nombre: 'Equipo',
        juego: Juego.lol,
        region: 'Test',
        prestigio: 80,
        presupuesto: 1000000,
        colorPrincipal: 0xFF000000,
        escudo: '',
      );
      expect(equipo.factorPoder, 1.0);

      equipo.factorPoder = 0.8;
      final copia = Equipo.fromJson(equipo.toJson());
      expect(copia.factorPoder, 0.8);
    });

    test('un equipo sin el campo nuevo carga con factor 1,0', () {
      final json = {
        'id': 'e1',
        'nombre': 'Equipo',
        'juego': 'lol',
        'region': 'Test',
        'prestigio': 80,
        'presupuesto': 1000000,
        'colorPrincipal': 0xFF000000,
        'escudo': '',
      };
      expect(Equipo.fromJson(json).factorPoder, 1.0);
    });
  });
}
