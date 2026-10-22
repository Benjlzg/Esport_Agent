// Pruebas de guardado de la auditoría (C1): los ids de jugador generados
// después de cargar una partida deben ser únicos, y las partidas v3–v6 sin
// el contador guardado deben seguir cargando.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';
import 'package:esport_agent/servicios/guardado.dart';

const int _semilla = 20251019;

Future<MotorJuego> _partidaNueva() async {
  final motor = MotorJuego(semilla: _semilla);
  await motor.nuevaPartida(nombre: 'Agente Prueba', pais: 'Chile');
  return motor;
}

/// Jugador ficticio con el mismo formato de id que genera el motor.
Jugador _jugadorGenerado(String id) => Jugador(
  id: id,
  nick: 'Generado $id',
  nombreReal: 'Generado $id',
  pais: 'Chile',
  edad: 19,
  juego: Juego.lol,
  rol: Juego.lol.roles.first,
  habilidad: 60,
  potencial: 80,
  equipoId: null,
  salarioAnual: 0,
  semanasContrato: 0,
  esReal: false,
);

/// Añade 50 jugadores p0000…p0049, como una partida que ya generó jóvenes.
void _anadirGenerados(EstadoPartida estado) {
  for (var i = 0; i < 50; i++) {
    estado.jugadores.add(_jugadorGenerado('p${i.toString().padLeft(4, '0')}'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'al cargar, el siguiente id de jugador continúa por encima del mayor',
    () async {
      final motor = await _partidaNueva();
      _anadirGenerados(motor.estado!);
      await guardarPartida(motor.estado!);

      // Un motor nuevo simula abrir la app de cero.
      final motorCargado = MotorJuego(semilla: _semilla);
      expect(await motorCargado.cargar(), ResultadoCarga.ok);
      expect(
        motorCargado.estado!.siguienteIdJugador,
        50,
        reason: 'Debe continuar después de p0049.',
      );

      // Quita un titular: el mercado de la semana 1 generará un reemplazo con
      // `_nuevoId`, que es justo el camino que antes repetía p0000.
      final est = motorCargado.estado!;
      final equipo = est.equipos.firstWhere((e) => e.juego == Juego.lol);
      final titular = est.jugadores.firstWhere(
        (j) => j.equipoId == equipo.id && !j.suplente,
      );
      est.jugadores.remove(titular);
      await motorCargado.avanzarSemana();

      final ids = est.jugadores.map((j) => j.id).toList();
      expect(
        ids.toSet().length,
        ids.length,
        reason: 'No puede haber dos jugadores con el mismo id.',
      );
      expect(
        ids.contains('p0050'),
        isTrue,
        reason: 'El primer id generado tras cargar debe ser p0050.',
      );
      expect(est.siguienteIdJugador, greaterThanOrEqualTo(51));
    },
  );

  test('las partidas v3–v6 sin contador cargan y lo reconstruyen', () async {
    final motor = await _partidaNueva();
    final estado = motor.estado!;
    _anadirGenerados(estado);
    final mapaBase = estado.toJson();

    for (final version in [3, 4, 5, 6]) {
      final mapa = Map<String, dynamic>.from(mapaBase);
      mapa['version'] = version;
      // Una partida vieja no tiene el contador ni los campos de las fases
      // posteriores; se eliminan para probar la lectura tolerante.
      for (final campo in [
        'siguienteIdJugador',
        'eventosPendientes',
        'ultimaSemanaEvento',
        'frecuenciaEventos',
        'semanasInversor',
        'semanasContactoGrande',
        'ceremoniaPendiente',
        'torneos',
        'palmares',
        'premios',
        'ofertas',
        'fichajesVentana',
        'rondasNegociacion',
        'paresBloqueados',
        'ingresosUltimaSemana',
        'gastosUltimaSemana',
        'finDelJuego',
      ]) {
        mapa.remove(campo);
      }
      SharedPreferences.setMockInitialValues({clavePartida: jsonEncode(mapa)});

      final cargado = MotorJuego(semilla: _semilla);
      expect(
        await cargado.cargar(),
        ResultadoCarga.ok,
        reason: 'La versión $version debe seguir siendo compatible.',
      );
      expect(
        cargado.estado!.siguienteIdJugador,
        50,
        reason:
            'El contador se reconstruye desde p0049 en la versión $version.',
      );
      expect(cargado.estado!.toJson()['version'], versionFormato);
    }

    expect(versionFormato, 7);
    expect(versionMinimaCompatible, 3);
  });
}
