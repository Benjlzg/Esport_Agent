// Pruebas del calendario tras unificar las etapas y extraer las fechas de
// liga (sección 5 de la auditoría).
import 'package:flutter_test/flutter_test.dart';

import 'package:esport_agent/logica/calendario.dart';
import 'package:esport_agent/modelos/competicion.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/partido.dart';

ResultadoSerie _resultado(int fecha, String local, String visitante) =>
    ResultadoSerie(
      fecha: fecha,
      etapa: 'Liga Split 1',
      localId: local,
      visitanteId: visitante,
      mapasLocal: 2,
      mapasVisitante: 0,
      ganadorId: local,
    );

void main() {
  test('la lista de etapas y etapaDeSemana usan la misma fuente', () {
    final etapas = listaEtapas();
    expect(etapas, hasLength(9));

    for (var semana = 1; semana <= 52; semana++) {
      final concreta = etapaDeSemana(semana);
      final base = etapas.firstWhere((etapa) => etapa.contiene(semana));
      expect(
        concreta.semanaInicio,
        base.semanaInicio,
        reason: 'semana $semana',
      );
      expect(concreta.semanaFin, base.semanaFin, reason: 'semana $semana');
      expect(concreta.tipo, base.tipo, reason: 'semana $semana');
    }
  });

  test('la fase regular muestra la fecha exacta', () {
    expect(etapaDeSemana(5).nombre, 'Split 1 · Fecha 1');
    expect(etapaDeSemana(18).nombre, 'Split 1 · Fecha 14');
    expect(etapaDeSemana(27).nombre, 'Split 2 · Fecha 1');
    expect(etapaDeSemana(40).nombre, 'Split 2 · Fecha 14');
  });

  test('la próxima fecha y la última jugada salen de los resultados', () {
    final competicion = Competicion(
      juego: Juego.lol,
      region: 'Test',
      division: 1,
      liga: 'Liga Test',
      equipoIds: ['a', 'b', 'c', 'd'],
      resultadosSplit1: [_resultado(1, 'a', 'b'), _resultado(1, 'c', 'd')],
    );

    expect(ultimaFechaJugada(competicion, 1), 1);
    expect(proximaFechaDeLiga(competicion, 1), 2);
    expect(proximaFechaDeLigaSeries(competicion, 1), hasLength(2));
    expect(resultadosUltimaFecha(competicion, 1), hasLength(2));

    // Un split sin resultados empieza en la fecha 1.
    expect(ultimaFechaJugada(competicion, 2), isNull);
    expect(proximaFechaDeLiga(competicion, 2), 1);
  });
}
