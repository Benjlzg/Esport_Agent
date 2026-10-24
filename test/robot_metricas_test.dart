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
  double semiancho = 0,
  int ingresos = 0,
  int gastoOjeadores = 0,
  int gastoStaff = 0,
  int abogadoNivel = 0,
  int relacionesPublicasNivel = 0,
  int ventas = 0,
  int ventasImporte = 0,
  int jovenesReclutados = 0,
  int jovenesColocados = 0,
  int jovenesSalidosLibres = 0,
  int sumaHabilidadColocaciones = 0,
  int ingresoAcademia = 0,
  int gastoAcademia = 0,
}) => FilaRobot(
  temporada: temporada,
  dineroInicio: dineroInicio,
  dineroFin: dineroFin,
  reputacionInicio: robotReputacionInicial,
  reputacionFin: reputacionFin,
  decisiones: 0,
  decisionesPorTipo: const {},
  fichajes: fichajes,
  ventas: ventas,
  eventos: 0,
  ofertasRespondidas: 0,
  semanasSinOpcion: 0,
  rachaMaxima: 0,
  perdidasPorRobo: perdidasPorRobo,
  semianchoMedioFichajes: semiancho,
  ingresosTemporada: ingresos,
  gastoOjeadores: gastoOjeadores,
  gastoStaff: gastoStaff,
  abogadoNivel: abogadoNivel,
  relacionesPublicasNivel: relacionesPublicasNivel,
  ventasImporte: ventasImporte,
  jovenesReclutados: jovenesReclutados,
  jovenesColocados: jovenesColocados,
  jovenesSalidosLibres: jovenesSalidosLibres,
  sumaHabilidadColocaciones: sumaHabilidadColocaciones,
  ingresoAcademia: ingresoAcademia,
  gastoAcademia: gastoAcademia,
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
  int ojeadoresNivel2 = 0,
  int top20ConRival = 0,
  int top20Considerados = 0,
  int academiaEnRivales = 0,
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
  ojeadoresNivel2: ojeadoresNivel2,
  top20ConRival: top20ConRival,
  top20Considerados: top20Considerados,
  academiaEnRivales: academiaEnRivales,
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

    test('mide los criterios de la Parte 3C', () {
      final resultado = _resultado(
        filas: [
          _fila(
            temporada: 1,
            semiancho: 15,
            ingresos: 100000,
            gastoOjeadores: 10000,
          ),
          _fila(
            temporada: 2,
            semiancho: 11,
            ingresos: 100000,
            gastoOjeadores: 10000,
          ),
          _fila(
            temporada: 3,
            semiancho: 7,
            ingresos: 100000,
            gastoOjeadores: 10000,
          ),
        ],
        ojeadoresNivel2: 2,
        top20ConRival: 8,
        top20Considerados: 20,
      );

      expect(resultado.cumpleCriterioOjeadores, isTrue);
      expect(resultado.cumpleCriterioSemiancho, isTrue);
      expect(resultado.cumpleCriterioGastoOjeadores, isTrue);
      expect(resultado.cumpleCriterioTalentosRivales, isTrue);
      expect(resultado.semianchoT1, 15);
      expect(resultado.semianchoT3, 7);

      final texto = seccionRobotMarkdown(resultado);
      expect(texto, contains('### Ojeadores (3C)'));
      expect(texto, contains('Ojeadores nivel 2: 2'));
    });

    test('los criterios 3C fallan fuera de rango', () {
      final resultado = _resultado(
        filas: [
          _fila(
            temporada: 1,
            semiancho: 7,
            ingresos: 100000,
            gastoOjeadores: 20000,
          ),
          _fila(
            temporada: 2,
            semiancho: 8,
            ingresos: 100000,
            gastoOjeadores: 20000,
          ),
          _fila(
            temporada: 3,
            semiancho: 9,
            ingresos: 100000,
            gastoOjeadores: 20000,
          ),
        ],
        ojeadoresNivel2: 1,
        top20ConRival: 9,
        top20Considerados: 20,
      );

      expect(resultado.cumpleCriterioOjeadores, isFalse);
      expect(resultado.cumpleCriterioSemiancho, isFalse);
      expect(resultado.cumpleCriterioGastoOjeadores, isFalse);
      expect(resultado.cumpleCriterioTalentosRivales, isFalse);
    });
  });

  group('staff del robot (3D)', () {
    test('el abogado se mide al final de la T2 y la RP al final de la T3', () {
      final resultado = _resultado(
        filas: [
          _fila(temporada: 1),
          _fila(temporada: 2, abogadoNivel: 2),
          _fila(temporada: 3, abogadoNivel: 2, relacionesPublicasNivel: 2),
        ],
      );

      expect(resultado.cumpleCriterioAbogado, isTrue);
      expect(resultado.cumpleCriterioRelacionesPublicas, isTrue);
    });

    test('falla si el abogado no llega a nivel 2 en la T2', () {
      final resultado = _resultado(
        filas: [
          _fila(temporada: 1),
          _fila(temporada: 2, abogadoNivel: 1),
          _fila(temporada: 3, abogadoNivel: 2, relacionesPublicasNivel: 2),
        ],
      );

      expect(resultado.cumpleCriterioAbogado, isFalse);
    });

    test('el gasto de staff no puede superar el 20 % de los ingresos', () {
      final dentro = _resultado(
        filas: [
          _fila(temporada: 1),
          _fila(temporada: 2),
          _fila(
            temporada: 3,
            ingresos: 100000,
            gastoStaff: 20000,
            abogadoNivel: 2,
            relacionesPublicasNivel: 2,
          ),
        ],
      );
      expect(dentro.cumpleCriterioGastoStaff, isTrue);
      expect(dentro.porcentajeGastoStaffT3, closeTo(0.20, 1e-9));

      final fuera = _resultado(
        filas: [
          _fila(temporada: 1),
          _fila(temporada: 2),
          _fila(
            temporada: 3,
            ingresos: 100000,
            gastoStaff: 20001,
            abogadoNivel: 2,
            relacionesPublicasNivel: 2,
          ),
        ],
      );
      expect(fuera.cumpleCriterioGastoStaff, isFalse);
    });

    test('el informe incluye la sección de staff y las ventas', () {
      final resultado = _resultado(
        filas: [
          _fila(temporada: 1, ventas: 2, ventasImporte: 30000),
          _fila(temporada: 2, abogadoNivel: 2),
          _fila(
            temporada: 3,
            abogadoNivel: 2,
            relacionesPublicasNivel: 2,
            ventas: 3,
            ventasImporte: 45000,
          ),
        ],
      );

      final texto = seccionRobotMarkdown(resultado);
      expect(texto, contains('### Staff (3D)'));
      expect(texto, contains('Abogado'));
      expect(texto, contains('Relaciones públicas'));
      expect(texto, contains('Ventas del robot por temporada'));
    });
  });

  group('academia del robot (3E)', () {
    test('mide reclutamiento, colocación, saldo y habilidad media', () {
      final resultado = _resultado(
        filas: [
          _fila(
            temporada: 1,
            jovenesReclutados: 2,
            jovenesColocados: 1,
            jovenesSalidosLibres: 0,
            sumaHabilidadColocaciones: 45,
            ingresoAcademia: 120000,
            gastoAcademia: 5000,
            ingresos: 300000,
          ),
          _fila(
            temporada: 2,
            jovenesColocados: 1,
            sumaHabilidadColocaciones: 46,
            ingresoAcademia: 130000,
            gastoAcademia: 4000,
            ingresos: 400000,
          ),
          _fila(
            temporada: 3,
            ingresos: 500000,
            abogadoNivel: 2,
            relacionesPublicasNivel: 2,
          ),
        ],
      );

      expect(resultado.jovenesReclutadosT1, 2);
      expect(resultado.colocacionesTotales, 2);
      expect(resultado.colocacionesAntesFinT2, 2);
      expect(resultado.saldoAcademia, 241000);
      expect(resultado.habilidadMediaColocacion, 45.5);
      expect(resultado.ingresoAcademiaT3, 0);
      expect(resultado.cumpleCriterioJovenesT1, isTrue);
      expect(resultado.cumpleCriterioColocacionT2, isTrue);
      expect(resultado.cumpleCriterioSaldoAcademia, isTrue);
      expect(resultado.cumpleCriterioHabilidadColocacion, isTrue);
      expect(resultado.cumpleCriterioAcademiaSinRivales, isTrue);
      expect(resultado.cumpleCriterioIngresoAcademia, isTrue);

      final texto = seccionRobotMarkdown(resultado);
      expect(texto, contains('### Academia (3E)'));
      expect(texto, contains('Jóvenes reclutados en la T1: 2'));
      expect(texto, contains('Saldo neto de la academia'));
      expect(texto, contains('Ingreso de academia de la T3'));
    });

    test('los criterios 3E fallan fuera de rango', () {
      final resultado = _resultado(
        filas: [
          _fila(
            temporada: 1,
            jovenesReclutados: 1,
            jovenesColocados: 0,
            ingresoAcademia: 1000,
            gastoAcademia: 150000,
            ingresos: 100000,
          ),
          _fila(temporada: 2, ingresos: 100000),
          _fila(
            temporada: 3,
            ingresoAcademia: 60000,
            gastoAcademia: 1000,
            ingresos: 100000,
          ),
        ],
        academiaEnRivales: 1,
      );

      expect(resultado.cumpleCriterioJovenesT1, isFalse);
      expect(resultado.cumpleCriterioColocacionT2, isFalse);
      expect(resultado.cumpleCriterioSaldoAcademia, isFalse);
      expect(resultado.cumpleCriterioHabilidadColocacion, isFalse);
      expect(resultado.cumpleCriterioAcademiaSinRivales, isFalse);
      expect(resultado.cumpleCriterioIngresoAcademia, isFalse);
    });
  });
}
