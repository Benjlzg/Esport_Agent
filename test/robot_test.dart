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
  }, timeout: const Timeout(Duration(minutes: 10)));
}
