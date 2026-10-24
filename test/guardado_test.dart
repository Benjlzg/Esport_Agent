// Pruebas de guardado: compatibilidad de versiones antiguas, contador de ids
// y migración de los agentes rivales (Parte 3A).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/agentes_rivales.dart';
import 'package:esport_agent/logica/motor_juego.dart';
import 'package:esport_agent/logica/ojeadores.dart';
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

  test('las partidas v3–v9 sin contador cargan y lo reconstruyen', () async {
    final motor = await _partidaNueva();
    final estado = motor.estado!;
    _anadirGenerados(estado);
    final mapaBase = estado.toJson();

    for (final version in [3, 4, 5, 6, 7, 8, 9]) {
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
        'agentesRivales',
        'staff',
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
      // Los campos de representación y de las Partes 3A/3B tampoco existían.
      mapa['jugadores'] = (mapa['jugadores'] as List).map((j) {
        final jugador = Map<String, dynamic>.from(j as Map);
        jugador.remove('semanasRepresentado');
        jugador.remove('agenteId');
        jugador.remove('satisfaccion');
        jugador.remove('semanasEnfriamientoAgente');
        jugador.remove('semanasEsperaConvencer');
        jugador.remove('expectativas');
        jugador.remove('quiereHablar');
        jugador.remove('semanasPromesaPendiente');
        jugador.remove('semanasContratoRepresentacion');
        jugador.remove('comisionSalarioContrato');
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
      if (version < 10) {
        expect(
          cargado.estado!.agentesRivales.length,
          inInclusiveRange(agentesRivalesMin, agentesRivalesMax),
          reason: 'La versión $version debe migrar con rivales generados.',
        );
      }
    }

    expect(versionFormato, 13);
    expect(versionMinimaCompatible, 3);
  });

  test('una partida v9 carga con rivales y mis jugadores intactos', () async {
    final motor = await _partidaNueva();
    final estado = motor.estado!;
    // Un representado mío y un jugador sin agente para comprobar que la
    // migración no toca a los míos y sí puede dar cartera a los rivales.
    final mio = estado.jugadores.firstWhere(
      (j) => j.equipoId != null && !j.representadoPorMi,
    );
    mio.representadoPorMi = true;
    mio.agenteId = 'yo';
    final libre = estado.jugadores.firstWhere((j) => j.equipoId == null);

    final mapa = Map<String, dynamic>.from(estado.toJson());
    mapa['version'] = 9;
    mapa.remove('agentesRivales');
    mapa.remove('staff');
    mapa['jugadores'] = (mapa['jugadores'] as List).map((j) {
      final jugador = Map<String, dynamic>.from(j as Map);
      jugador.remove('agenteId');
      jugador.remove('satisfaccion');
      jugador.remove('semanasEnfriamientoAgente');
      jugador.remove('semanasEsperaConvencer');
      jugador.remove('expectativas');
      jugador.remove('quiereHablar');
      jugador.remove('semanasPromesaPendiente');
      jugador.remove('semanasContratoRepresentacion');
      jugador.remove('comisionSalarioContrato');
      return jugador;
    }).toList();
    SharedPreferences.setMockInitialValues({clavePartida: jsonEncode(mapa)});

    final cargado = MotorJuego(semilla: _semilla);
    expect(await cargado.cargar(), ResultadoCarga.ok);

    final est = cargado.estado!;
    expect(
      est.agentesRivales.length,
      inInclusiveRange(agentesRivalesMin, agentesRivalesMax),
    );
    expect(
      est.agentesRivales.map((r) => r.id).toSet().length,
      est.agentesRivales.length,
    );
    final jugadorMio = est.jugadores.firstWhere((j) => j.id == mio.id);
    expect(jugadorMio.representadoPorMi, isTrue);
    expect(jugadorMio.agenteId, 'yo');
    expect(jugadorMio.satisfaccion, 70);
    final jugadorLibre = est.jugadores.firstWhere((j) => j.id == libre.id);
    // Puede haber quedado sin agente o con uno, pero nunca representado por mí.
    expect(jugadorLibre.representadoPorMi, isFalse);
    expect(est.toJson()['version'], 13);
  });

  test(
    'una partida v11 carga con ojeadores vacíos y potencial exacto',
    () async {
      final motor = await _partidaNueva();
      final estado = motor.estado!;
      final mapa = Map<String, dynamic>.from(estado.toJson());
      mapa['version'] = 11;
      mapa.remove('ojeadores');
      mapa.remove('staff');
      // Una v11 no tenía ninguno de los campos de potencial oculto.
      mapa['jugadores'] = (mapa['jugadores'] as List).map((j) {
        final jugador = Map<String, dynamic>.from(j as Map);
        jugador.remove('errorPotencial');
        jugador.remove('semanasObservado');
        jugador.remove('potencialVisibleMin');
        jugador.remove('potencialVisibleMax');
        jugador.remove('oculto');
        return jugador;
      }).toList();
      SharedPreferences.setMockInitialValues({clavePartida: jsonEncode(mapa)});

      final cargado = MotorJuego(semilla: _semilla);
      expect(await cargado.cargar(), ResultadoCarga.ok);
      final est = cargado.estado!;

      expect(est.ojeadores, isEmpty);
      expect(est.staff, isEmpty);
      expect(est.toJson()['version'], 13);
      for (final jugador in est.jugadores) {
        expect(
          jugador.errorPotencial,
          errorPotencialDeterminista(jugador.id),
          reason: 'El error de ${jugador.id} debe ser determinista y sin RNG.',
        );
        expect(jugador.potencialVisibleMin, isNull);
        expect(jugador.potencialVisibleMax, isNull);
        expect(jugador.semanasObservado, 0);
        expect(jugador.oculto, isFalse);
        expect(
          textoPotencial(jugador),
          '${jugador.potencial}',
          reason:
              'Una partida vieja conserva el potencial exacto que ya sabía.',
        );
      }
    },
  );

  test('una partida v12 carga con staff vacío y sin gastar RNG', () async {
    final motor = await _partidaNueva();
    final mapa = Map<String, dynamic>.from(motor.estado!.toJson());
    mapa['version'] = 12;
    // Una v12 no tenía staff: la lista debe quedar vacía y la migración no
    // puede consumir números aleatorios.
    mapa.remove('staff');
    SharedPreferences.setMockInitialValues({clavePartida: jsonEncode(mapa)});

    final cargado = MotorJuego(semilla: _semilla);
    expect(await cargado.cargar(), ResultadoCarga.ok);
    expect(cargado.estado!.staff, isEmpty);
    expect(cargado.estado!.toJson()['version'], 13);

    // El motor recién creado no ha usado su RNG al cargar una v12 válida.
    final esperado = Random(_semilla);
    for (var i = 0; i < 5; i++) {
      expect(cargado.rnd.nextDouble(), esperado.nextDouble());
    }
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
      'staff',
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
