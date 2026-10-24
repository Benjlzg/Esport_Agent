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
  }, timeout: const Timeout(Duration(minutes: 10)));
}
