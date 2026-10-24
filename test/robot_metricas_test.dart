// Pruebas rápidas de las métricas del robot (corrección 2.5 B1).
//
// La simulación completa del robot es lenta y lleva la etiqueta `lento`.
// Estas pruebas comprueban, sin simular, que el informe usa la economía real
// ($50.000 y reputación 10) y que resume bien el dinero y los ingresos.
import 'package:flutter_test/flutter_test.dart';

import 'apoyo/robot_jugador.dart';

/// Fila mínima de una temporada del robot.
FilaRobot _fila({
  int temporada = 1,
  int dineroInicio = robotDineroInicial,
  int dineroFin = 60000,
  int reputacionFin = robotReputacionInicial,
  int fichajes = 0,
  int perdidasPorRobo = 0,
}) => FilaRobot(
  temporada: temporada,
  dineroInicio: dineroInicio,
  dineroFin: dineroFin,
  reputacionInicio: robotReputacionInicial,
  reputacionFin: reputacionFin,
  decisiones: 0,
  decisionesPorTipo: const {},
  fichajes: fichajes,
  ventas: 0,
  eventos: 0,
  ofertasRespondidas: 0,
  semanasSinOpcion: 0,
  rachaMaxima: 0,
  perdidasPorRobo: perdidasPorRobo,
);

/// Resultado mínimo para probar los cálculos del informe.
ResultadoRobot _resultado({
  List<FilaRobot>? filas,
  bool quiebra = false,
  int dineroMinimo = robotDineroInicial,
  int? temporadaMenosDinero = 1,
  int? semanaMenosDinero = 1,
  Map<String, int>? ingresos,
  Map<String, int>? gastos,
  int jugadoresSinAgenteIniciales = 0,
  int jugadoresSinAgenteEnRivales = 0,
}) => ResultadoRobot(
  filas: filas ?? [_fila()],
  rachaMaxima: 0,
  semanasSinOpcion: 0,
  milisegundos: 0,
  quiebra: quiebra,
  dineroMinimo: dineroMinimo,
  temporadaMenosDinero: temporadaMenosDinero,
  semanaMenosDinero: semanaMenosDinero,
  ingresosPorFuente:
      ingresos ?? {for (final fuente in robotFuentesIngreso) fuente: 0},
  gastosPorFuente:
      gastos ?? {for (final fuente in robotFuentesGasto) fuente: 0},
  jugadoresSinAgenteIniciales: jugadoresSinAgenteIniciales,
  jugadoresSinAgenteEnRivales: jugadoresSinAgenteEnRivales,
);

void main() {
  group('economía real del robot (B1)', () {
    test('empieza con el mismo dinero y reputación que un jugador nuevo', () {
      expect(robotDineroInicial, 50000);
      expect(robotReputacionInicial, 10);
      expect(robotDineroMaximoFinal, 5000000);
    });

    test('el criterio falla si quiebra o supera los 5 millones', () {
      expect(
        _resultado(filas: [_fila(dineroFin: 5000000)]).dentroDelCriterio,
        isTrue,
      );
      expect(
        _resultado(filas: [_fila(dineroFin: 5000001)]).dentroDelCriterio,
        isFalse,
      );
      expect(
        _resultado(
          quiebra: true,
          filas: [_fila(dineroFin: 0)],
        ).dentroDelCriterio,
        isFalse,
      );
    });

    test('sin temporadas jugadas usa el dinero inicial', () {
      expect(_resultado(filas: const []).dineroFinal, robotDineroInicial);
    });

    test('elige la fuente de ingreso con más dinero', () {
      final resultado = _resultado(
        ingresos: {
          ingresoSalarios: 1000,
          ingresoTraspasos: 5000,
          ingresoRenovaciones: 0,
          ingresoEventos: 2000,
        },
      );

      expect(resultado.fuentePrincipalIngresos?.key, ingresoTraspasos);
      expect(resultado.fuentePrincipalIngresos?.value, 5000);
      expect(
        _resultado(
          ingresos: {for (final fuente in robotFuentesIngreso) fuente: 0},
        ).fuentePrincipalIngresos,
        isNull,
      );
    });

    test('el informe incluye dinero, mínimo y fuente principal', () {
      final texto = seccionRobotMarkdown(
        _resultado(
          filas: [_fila(dineroFin: 120000)],
          dineroMinimo: 40000,
          temporadaMenosDinero: 1,
          semanaMenosDinero: 3,
          ingresos: {
            ingresoSalarios: 30000,
            ingresoTraspasos: 90000,
            ingresoRenovaciones: 0,
            ingresoEventos: 5000,
          },
        ),
      );

      expect(texto, contains('Economía real'));
      expect(texto, contains('50.000'));
      expect(texto, contains('Semana con menos dinero: T1 · S3'));
      expect(texto, contains('Principal fuente de ingresos: Traspasos'));
      expect(texto, contains('Criterio B1'));
      expect(texto, contains('**cumple**'));
    });

    test('ingresos y gastos cuadran con el dinero final', () {
      final resultado = _resultado(
        filas: [_fila(dineroFin: 55000)],
        ingresos: {
          ingresoSalarios: 8000,
          ingresoTraspasos: 2000,
          ingresoRenovaciones: 0,
          ingresoEventos: 0,
        },
        gastos: {
          gastoOficina: 3000,
          gastoReclutamientos: 1500,
          gastoEventos: 500,
        },
      );

      expect(resultado.ingresosTotales, 10000);
      expect(resultado.gastosTotales, 5000);
      expect(resultado.cuadra, isTrue);
      expect(resultado.descuadre, 0);

      final texto = seccionRobotMarkdown(resultado);
      expect(texto, contains('### Gastos'));
      expect(texto, contains('Reclutamientos'));
      expect(texto, contains('### Cuadre del dinero'));
      expect(texto, contains('0 (cuadra)'));
    });

    test('mide los criterios de la Parte 3A por temporada', () {
      final resultado = _resultado(
        filas: [
          _fila(temporada: 1, fichajes: 5, perdidasPorRobo: 1),
          _fila(temporada: 2, fichajes: 6, perdidasPorRobo: 0),
          _fila(
            temporada: 3,
            fichajes: 7,
            reputacionFin: 43,
            perdidasPorRobo: 0,
          ),
        ],
        jugadoresSinAgenteIniciales: 100,
        jugadoresSinAgenteEnRivales: 35,
      );

      expect(resultado.maxPerdidasPorRobo, 1);
      expect(resultado.cumpleCriterioRobos, isTrue);
      expect(resultado.minimoFichajesPorTemporada, 5);
      expect(resultado.cumpleCriterioFichajes, isTrue);
      expect(resultado.porcentajeEnRivales, closeTo(0.35, 0.0001));
      expect(resultado.cumpleCriterioRivales, isTrue);
      expect(resultado.cumpleCriterioReputacion, isTrue);

      final texto = seccionRobotMarkdown(resultado);
      expect(texto, contains('Robos'));
      expect(texto, contains('| 1 |'));
    });

    test('los criterios 3A fallan fuera de rango', () {
      final resultado = _resultado(
        filas: [
          _fila(temporada: 1, fichajes: 4, perdidasPorRobo: 2),
          _fila(temporada: 2, fichajes: 3, reputacionFin: 29),
        ],
        jugadoresSinAgenteIniciales: 100,
        jugadoresSinAgenteEnRivales: 41,
      );

      expect(resultado.cumpleCriterioRobos, isFalse);
      expect(resultado.cumpleCriterioFichajes, isFalse);
      expect(resultado.cumpleCriterioRivales, isFalse);
      expect(resultado.cumpleCriterioReputacion, isFalse);
    });
  });
}
