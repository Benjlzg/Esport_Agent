// Jugador robot de 3 temporadas (Fase 2.5, paso 8). Juega a nivel de motor,
// escribe su sección en INFORME_BALANCE.md y falla si la agencia quiebra o
// deja una racha preocupante sin opciones.
@Tags(['lento'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apoyo/robot_jugador.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('el robot sobrevive 3 temporadas sin rachas preocupantes', () async {
    final resultado = await ejecutarRobotDePrueba();

    // El informe se escribe antes de fallar para poder diagnosticar.
    actualizarSeccionRobot(resultado);

    expect(
      resultado.quiebra,
      isFalse,
      reason: 'El robot quebró durante las 3 temporadas.',
    );
    expect(
      resultado.rachaPreocupanteDetectada,
      isFalse,
      reason:
          'Racha de ${resultado.rachaMaxima} semanas sin ninguna opción '
          '(preocupante desde $rachaPreocupante).',
    );
    expect(resultado.filas, hasLength(temporadasRobot));
    expect(
      resultado.cuadra,
      isTrue,
      reason:
          'El dinero final no cuadra con ingresos y gastos '
          '(descuadre ${resultado.descuadre}).',
    );

    // Criterios de balance de la Parte 3A.
    expect(
      resultado.cumpleCriterioRobos,
      isTrue,
      reason:
          'El robot perdió ${resultado.maxPerdidasPorRobo} representados por '
          'robo en una temporada (máximo 1).',
    );
    expect(
      resultado.cumpleCriterioFichajes,
      isTrue,
      reason:
          'El robot solo hizo ${resultado.minimoFichajesPorTemporada} '
          'reclutamientos en una temporada (mínimo 5).',
    );
    expect(
      resultado.cumpleCriterioRivales,
      isTrue,
      reason:
          'Los rivales se quedaron con '
          '${(resultado.porcentajeEnRivales * 100).toStringAsFixed(1)} % de '
          'los jugadores que empezaron sin agente (máximo 40 %).',
    );
    expect(
      resultado.cumpleCriterioReputacion,
      isTrue,
      reason:
          'La reputación final fue ${resultado.reputacionFinal} '
          '(meta 30–45).',
    );

    // Criterios de balance de la Parte 3B.
    expect(
      resultado.cumpleCriterioPerdidasSatisfaccion,
      isTrue,
      reason:
          'El robot perdió ${resultado.maxPerdidasPorSatisfaccion} '
          'representados por insatisfacción o robo en una temporada '
          '(máximo 2).',
    );
    expect(
      resultado.cumpleCriterioSatisfaccion,
      isTrue,
      reason:
          'La satisfacción media final fue '
          '${resultado.satisfaccionMedia.toStringAsFixed(1)} (meta 55–85).',
    );
    expect(
      resultado.cumpleCriterioComision,
      isTrue,
      reason:
          'La comisión media fue '
          '${(resultado.comisionMedia * 100).toStringAsFixed(1)} % '
          '(meta 4–6 %).',
    );
    expect(
      resultado.cumpleCriterioPromesas,
      isTrue,
      reason:
          'Hubo ${resultado.promesasIncumplidas} promesas incumplidas '
          '(máximo 2).',
    );

    // Criterios de balance de la Parte 3C.
    expect(
      resultado.cumpleCriterioOjeadores,
      isTrue,
      reason:
          'El robot tiene ${resultado.ojeadoresNivel2} ojeadores nivel 2 '
          '(meta 2).',
    );
    expect(
      resultado.cumpleCriterioSemiancho,
      isTrue,
      reason:
          'El semiancho medio de fichajes no bajó de T1 a T3: '
          '${resultado.semianchoT1.toStringAsFixed(1)} → '
          '${resultado.semianchoT3.toStringAsFixed(1)}.',
    );
    expect(
      resultado.cumpleCriterioGastoOjeadores,
      isTrue,
      reason:
          'El gasto en ojeadores de la T3 supera el 15 % de los ingresos '
          '(gasto ${resultado.filas.isEmpty ? 0 : resultado.filas.last.gastoOjeadores}, '
          'ingresos ${resultado.filas.isEmpty ? 0 : resultado.filas.last.ingresosTemporada}).',
    );
    expect(
      resultado.cumpleCriterioTalentosRivales,
      isTrue,
      reason:
          'Los rivales tienen ${resultado.top20ConRival} de los '
          '${resultado.top20Considerados} potenciales reales más altos '
          '(máximo 40 %).',
    );

    // Criterios de balance de la Parte 3D.
    expect(
      resultado.cumpleCriterioAbogado,
      isTrue,
      reason:
          'El abogado no llegó a nivel $robotNivelStaff en la T2 '
          '(nivel final: ${resultado.filas.length >= 2 ? resultado.filas[1].abogadoNivel : 0}).',
    );
    expect(
      resultado.cumpleCriterioRelacionesPublicas,
      isTrue,
      reason:
          'Las relaciones públicas no llegaron a nivel $robotNivelStaff en '
          'la T3 (nivel final: ${resultado.relacionesPublicasNivelFinal}).',
    );
    expect(
      resultado.cumpleCriterioGastoStaff,
      isTrue,
      reason:
          'El gasto en staff de la T3 supera el 20 % de los ingresos '
          '(gasto ${resultado.gastoStaffT3}, ingresos ${resultado.ingresosT3}).',
    );
    expect(
      resultado.cumpleDineroMinimoFinal,
      isTrue,
      reason:
          'El robot terminó la T3 con ${resultado.dineroFinal} '
          '(mínimo $robotDineroMinimoFinal).',
    );

    // Criterios de balance de la Parte 3E (academia). Los reclutamientos de
    // academia no cuentan para el criterio de 3A.
    expect(
      resultado.cumpleCriterioJovenesT1,
      isTrue,
      reason:
          'El robot reclutó ${resultado.jovenesReclutadosT1} jóvenes en la T1 '
          '(meta $robotJovenesT1).',
    );
    expect(
      resultado.cumpleCriterioColocacionT2,
      isTrue,
      reason:
          'El robot colocó ${resultado.colocacionesAntesFinT2} jóvenes antes '
          'de terminar la T2 (meta ≥ 1).',
    );
    expect(
      resultado.cumpleCriterioSaldoAcademia,
      isTrue,
      reason:
          'El saldo de la academia fue ${resultado.saldoAcademia} '
          '(pérdida máxima 30.000).',
    );
    expect(
      resultado.cumpleCriterioHabilidadColocacion,
      isTrue,
      reason:
          'La habilidad media al colocar fue '
          '${resultado.habilidadMediaColocacion.toStringAsFixed(1)} '
          '(meta 45–65).',
    );
    expect(
      resultado.cumpleCriterioAcademiaSinRivales,
      isTrue,
      reason:
          '${resultado.academiaEnRivales} jóvenes de la academia acabaron con '
          'un rival (meta 0).',
    );
    expect(
      resultado.cumpleCriterioIngresoAcademia,
      isTrue,
      reason:
          'El ingreso de academia de la T3 fue '
          '${(resultado.porcentajeIngresoAcademiaT3 * 100).toStringAsFixed(1)} '
          '% de los ingresos (meta ≤ 20 %).',
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
}
