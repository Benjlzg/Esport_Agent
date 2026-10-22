// Pruebas de guardado de la auditoría (C1): los ids de jugador generados
// después de cargar una partida deben ser únicos, y las partidas v3–v7 sin
// el contador guardado deben seguir cargando.
import 'dart:convert';
import 'dart:io';

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

  late Directory carpeta;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    carpeta = await Directory.systemTemp.createTemp('esport_agent_guardado_');
    repositorioPartida = RepositorioPartida(directorio: () async => carpeta);
  });

  tearDown(() async {
    if (await carpeta.exists()) await carpeta.delete(recursive: true);
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

  test('las partidas v3–v8 sin contador cargan y lo reconstruyen', () async {
    final motor = await _partidaNueva();
    final estado = motor.estado!;
    _anadirGenerados(estado);
    final mapaBase = estado.toJson();

    for (final version in [3, 4, 5, 6, 7, 8]) {
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
        'ingresosSemanaEnCurso',
        'gastosSemanaEnCurso',
        'finDelJuego',
      ]) {
        mapa.remove(campo);
      }
      // El campo de semanas de representación también es nuevo (I1).
      mapa['jugadores'] = (mapa['jugadores'] as List).map((j) {
        final jugador = Map<String, dynamic>.from(j as Map);
        jugador.remove('semanasRepresentado');
        return jugador;
      }).toList();
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

    expect(versionFormato, 9);
    expect(versionMinimaCompatible, 3);
  });

  test('guarda en un archivo con respaldo .bak y sin temporales', () async {
    final motor = await _partidaNueva();
    // Carpeta nueva para que el primer guardado de este test no encuentre un
    // archivo anterior de `nuevaPartida`.
    final carpetaNueva = await Directory('${carpeta.path}/primera')
        .create(recursive: true);
    repositorioPartida = RepositorioPartida(
      directorio: () async => carpetaNueva,
    );
    final principal = File('${carpetaNueva.path}/partida_esports_agent.json');
    final respaldo = File('${principal.path}.bak');

    await guardarPartida(motor.estado!);

    expect(await principal.exists(), isTrue);
    expect(await File('${principal.path}.tmp').exists(), isFalse);
    // Todavía no hay copia porque es el primer guardado de este test.
    expect(await respaldo.exists(), isFalse);

    motor.agente.dinero = 123456;
    await guardarPartida(motor.estado!);

    expect(await respaldo.exists(), isTrue);
    expect(await File('${principal.path}.tmp').exists(), isFalse);

    final carga = await cargarPartida();
    expect(carga.resultado, ResultadoCarga.ok);
    expect(carga.estado!.agente.dinero, 123456);
  });

  test(
    'recupera la partida desde el respaldo si el principal está dañado',
    () async {
      final motor = await _partidaNueva();
      motor.agente.dinero = 111111;
      await guardarPartida(motor.estado!);
      motor.agente.dinero = 222222;
      await guardarPartida(motor.estado!);

      final principal = File('${carpeta.path}/partida_esports_agent.json');
      await principal.writeAsString('esto no es json');

      final carga = await cargarPartida();
      expect(carga.resultado, ResultadoCarga.ok);
      // El respaldo es el guardado anterior, con 111.111.
      expect(carga.estado!.agente.dinero, 111111);
      // Además, el principal se repara con el contenido del respaldo.
      final reparado = jsonDecode(await principal.readAsString());
      expect(reparado['agente']['dinero'], 111111);
    },
  );

  test('I14: repara competiciones, plantillas y torneos de una v4', () async {
    final motor = await _partidaNueva();
    final estado = motor.estado!;
    estado.semana = 30;
    // Simula una partida v4 a la que le faltan los datos derivados.
    estado.competiciones = [];
    estado.torneos = [];

    final mapa = Map<String, dynamic>.from(estado.toJson());
    mapa['version'] = 4;
    for (final campo in [
      'siguienteIdJugador',
      'eventosPendientes',
      'ultimaSemanaEvento',
      'frecuenciaEventos',
      'semanasInversor',
      'semanasContactoGrande',
      'ceremoniaPendiente',
      'torneos',
      'competiciones',
      'palmares',
      'premios',
      'ofertas',
      'fichajesVentana',
      'rondasNegociacion',
      'paresBloqueados',
      'ingresosUltimaSemana',
      'gastosUltimaSemana',
      'ingresosSemanaEnCurso',
      'gastosSemanaEnCurso',
      'finDelJuego',
    ]) {
      mapa.remove(campo);
    }
    SharedPreferences.setMockInitialValues({clavePartida: jsonEncode(mapa)});

    final cargado = MotorJuego(semilla: _semilla);
    expect(await cargado.cargar(), ResultadoCarga.ok);

    // 1) Las ligas se regeneran.
    expect(cargado.estado!.competiciones, isNotEmpty);
    // 2) Cada equipo vuelve a tener sus 5 titulares.
    for (final equipo in cargado.estado!.equipos) {
      final titulares = cargado.estado!.jugadores
          .where((j) => j.equipoId == equipo.id && !j.suplente)
          .map((j) => j.rol)
          .toSet();
      expect(titulares, containsAll(equipo.juego.roles));
    }
    // 3) El Torneo de Mitad de la temporada en curso se reconstruye porque
    //    la semana 30 ya pasó de las semanas 21–22.
    final mitades = cargado.estado!.torneos.where(
      (t) => t.temporada == 1 && t.tipo.name == 'mitad',
    );
    expect(mitades, hasLength(4));

    // 4) El original migrado queda como copia .bak antes de repararlo.
    final respaldo = File('${carpeta.path}/partida_esports_agent.json.bak');
    expect(await respaldo.exists(), isTrue);
    final original = jsonDecode(await respaldo.readAsString());
    expect(original['version'], 4);
  });

  test('migra una partida antigua de shared_preferences al archivo', () async {
    final motor = await _partidaNueva();
    motor.agente.dinero = 987654;
    final texto = jsonEncode(motor.estado!.toJson());
    SharedPreferences.setMockInitialValues({clavePartida: texto});

    final carga = await cargarPartida();
    expect(carga.resultado, ResultadoCarga.ok);
    expect(carga.estado!.agente.dinero, 987654);

    final principal = File('${carpeta.path}/partida_esports_agent.json');
    expect(await principal.exists(), isTrue);
    // La clave antigua se elimina después de migrar.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(clavePartida), isFalse);
  });
}
