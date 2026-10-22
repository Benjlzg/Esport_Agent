// Prueba de la comisión semanal de salario: con un salario anual conocido,
// la comisión debe ser el 5 % del salario semanal y no debe mezclarse con los
// traspasos ni los eventos del resumen semanal.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/formulas.dart';
import 'package:esport_agent/logica/motor_juego.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'la comisión semanal de un jugador con salario conocido es el 5 %',
    () async {
      final motor = MotorJuego(semilla: 20251019);
      await motor.nuevaPartida(nombre: 'Agente Prueba', pais: 'Chile');
      final estado = motor.estado!;

      // Solo este jugador estará representado, así la comisión semanal es
      // exactamente la suya.
      for (final jugador in estado.jugadores) {
        jugador.representadoPorMi = false;
        jugador.semanasInactivo = 0;
      }
      final jugador = estado.jugadores.firstWhere(
        (j) => j.equipoId != null && j.semanasContrato > 2,
      );
      jugador.representadoPorMi = true;
      jugador.salarioAnual = 520000; // 10.000 semanales; 5 % = 500.
      jugador.semanasContrato = 100;
      estado.semanasInversor = 0;
      estado.ingresosSemanaEnCurso = 0;
      estado.gastosSemanaEnCurso = 0;

      final salarioSemanal = calcularSalarioSemanal(jugador.salarioAnual);
      final comisionEsperada = (salarioSemanal * comisionSalario).round();
      final dineroAntes = motor.agente.dinero;

      expect(salarioSemanal, 10000);
      expect(comisionEsperada, 500);

      await motor.avanzarSemana();

      expect(
        motor.metricas.comisionesSalarioUltimaSemana,
        comisionEsperada,
        reason: 'La métrica debe separar la comisión de salario del resto.',
      );
      expect(
        estado.ingresosUltimaSemana,
        comisionEsperada,
        reason:
            'Sin traspasos ni eventos, el ingreso de la semana es la comisión.',
      );
      expect(estado.gastosUltimaSemana, gastoOficinaSemanal);
      expect(
        motor.agente.dinero,
        dineroAntes + comisionEsperada - gastoOficinaSemanal,
        reason: 'La comisión se cobra y la oficina se paga en la misma semana.',
      );
    },
  );
}
