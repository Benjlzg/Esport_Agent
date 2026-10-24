// Pruebas de la Parte 3D: staff de la agencia.
//
// Cubren el modelo, los efectos del abogado/RP/preparador, los salarios y las
// acciones de contratar, mejorar y despedir. Las pruebas de eventos usan el
// mismo punto de resolución que el juego para comprobar la idempotencia.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esport_agent/logica/eventos.dart';
import 'package:esport_agent/logica/formulas.dart';
import 'package:esport_agent/logica/negociacion.dart';
import 'package:esport_agent/logica/progresion.dart';
import 'package:esport_agent/logica/staff.dart';
import 'package:esport_agent/modelos/agente.dart';
import 'package:esport_agent/modelos/estado_partida.dart';
import 'package:esport_agent/modelos/evento.dart';
import 'package:esport_agent/modelos/juego.dart';
import 'package:esport_agent/modelos/jugador.dart';
import 'package:esport_agent/modelos/staff.dart';

import 'apoyo/entorno_simulacion.dart';

/// Jugador mínimo para las pruebas de lógica.
Jugador _jugador(
  String id, {
  int edad = 22,
  int habilidad = 70,
  int potencial = 80,
  bool representadoPorMi = true,
  int moral = 70,
  String? equipoId,
}) => Jugador(
  id: id,
  nick: id.toUpperCase(),
  nombreReal: id,
  pais: 'Test',
  edad: edad,
  juego: Juego.lol,
  rol: 'Mid',
  habilidad: habilidad,
  potencial: potencial,
  moral: moral,
  equipoId: equipoId,
  representadoPorMi: representadoPorMi,
  salarioAnual: 100000,
  semanasContrato: 100,
);

/// Miembro de staff de prueba.
MiembroStaff _staff(RolStaff rol, int nivel, {String? id, String? nombre}) =>
    MiembroStaff(
      id: id ?? 's${rol.index}',
      rol: rol,
      nombre: nombre ?? rol.etiqueta,
      nivel: nivel,
    );

/// Estado mínimo para probar efectos sin cargar el mundo entero.
EstadoPartida _estado({
  List<Jugador>? jugadores,
  List<MiembroStaff>? staff,
  int dinero = 100000,
  int reputacion = 20,
}) => EstadoPartida(
  agente: Agente(
    nombre: 'Test',
    pais: 'Test',
    dinero: dinero,
    reputacion: reputacion,
  ),
  jugadores: jugadores ?? [],
  equipos: [],
  noticias: [],
  staff: staff ?? [],
);

/// Evento pendiente con la definición real del catálogo.
EventoPendiente _evento(
  String definicionId, {
  String? jugadorId,
  int costoBaseA = 0,
}) => EventoPendiente(
  id: 'ev_test_$definicionId',
  definicionId: definicionId,
  jugadorId: jugadorId,
  titulo: 'Evento de prueba',
  descripcion: 'Evento de prueba',
  esDecision: true,
  opcionA: 'Opción A',
  opcionB: 'Opción B',
  costoBaseA: costoBaseA,
  temporada: 1,
  semana: 1,
);

/// Ejecuta un evento pendiente con los índices del estado.
ResultadoEvento _resolver(
  EstadoPartida estado,
  EventoPendiente evento, {
  int opcion = 0,
  Random? rnd,
}) {
  final indiceJugadores = {for (final j in estado.jugadores) j.id: j};
  return resolverEvento(
    estado: estado,
    indiceJugadores: indiceJugadores,
    indiceEquipos: {},
    rnd: rnd ?? Random(1),
    nuevoIdJugador: () => 'nuevo',
    evento: evento,
    opcion: opcion,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('modelo del staff', () {
    test('rol desconocido cae en abogado y el nivel se acota a 1–5', () {
      final desconocido = MiembroStaff.fromJson({
        'id': 's9',
        'rol': 'entrenador_de_la_duda',
        'nombre': 'Prueba',
        'nivel': 99,
      });
      expect(desconocido.rol, RolStaff.abogado);
      expect(desconocido.nivel, 5);

      final bajo = MiembroStaff.fromJson({
        'id': 's10',
        'rol': 'preparador',
        'nombre': 'Prueba',
        'nivel': -4,
      });
      expect(bajo.rol, RolStaff.preparador);
      expect(bajo.nivel, 1);
    });

    test('serialización ida y vuelta', () {
      final original = _staff(RolStaff.relacionesPublicas, 3);
      final copia = MiembroStaff.fromJson(original.toJson());
      expect(copia.id, original.id);
      expect(copia.rol, original.rol);
      expect(copia.nombre, original.nombre);
      expect(copia.nivel, original.nivel);
    });

    test('un estado con puestos duplicados deja uno por rol', () {
      final abogado1 = _staff(RolStaff.abogado, 2, id: 's000', nombre: 'Uno');
      final abogado2 = _staff(RolStaff.abogado, 4, id: 's001', nombre: 'Dos');
      final rp = _staff(RolStaff.relacionesPublicas, 3, id: 's002');
      final estado = _estado(staff: [abogado1, abogado2, rp]);

      final cargado = EstadoPartida.fromJson(estado.toJson());
      expect(cargado.staff, hasLength(2));
      expect(cargado.staff.first.rol, RolStaff.abogado);
      expect(cargado.staff.first.nivel, 2);
      expect(cargado.staff.last.rol, RolStaff.relacionesPublicas);

      normalizarStaff(estado);
      expect(estado.staff, hasLength(2));
      expect(estado.staff.first.id, 's000');
    });
  });

  group('abogado', () {
    test('margen por nivel y tope con el contacto grande', () {
      for (var nivel = 0; nivel <= 5; nivel++) {
        expect(
          margenAceptacionTotal(nivelAbogado: nivel),
          closeTo(0.02 * nivel, 1e-9),
        );
      }

      // Abogado nivel 5 solo ya llega al tope; con el contacto grande de 2E
      // no se supera +0,10 y el límite de aceptación queda en 1,15.
      final ambos = margenAceptacionTotal(
        nivelAbogado: 5,
        margenContacto: 0.10,
      );
      expect(ambos, closeTo(0.10, 1e-9));
      expect(limiteAceptacion + ambos, closeTo(1.15, 1e-9));

      // Nivel 2 + contacto también se queda en el tope.
      final nivel2 = margenAceptacionTotal(
        nivelAbogado: 2,
        margenContacto: 0.10,
      );
      expect(nivel2, closeTo(0.10, 1e-9));
    });

    test('el margen cambia la respuesta a un precio por encima del 5 %', () {
      const valor = 100000;
      const precio = 106000; // 1,06 del valor

      final sinAbogado = calcularRespuesta(
        precioPedido: precio,
        valorMercado: valor,
        rnd: Random(1),
      );
      expect(sinAbogado.respuesta, RespuestaEquipo.contraoferta);

      final nivel1 = calcularRespuesta(
        precioPedido: precio,
        valorMercado: valor,
        rnd: Random(1),
        margenExtraAceptacion: margenAceptacionTotal(nivelAbogado: 1),
      );
      expect(nivel1.respuesta, RespuestaEquipo.acepta);
    });

    test('la tasa de aceptación con abogado 2 y 5 no baja de la base', () {
      int aceptaciones(int nivel) {
        final rnd = Random(20251019);
        var total = 0;
        for (var porcentaje = 100; porcentaje <= 120; porcentaje++) {
          final precio = (100000 * porcentaje / 100).round();
          final resultado = calcularRespuesta(
            precioPedido: precio,
            valorMercado: 100000,
            rnd: rnd,
            margenExtraAceptacion: margenAceptacionTotal(nivelAbogado: nivel),
          );
          if (resultado.respuesta == RespuestaEquipo.acepta) total++;
        }
        return total;
      }

      final sinAbogado = aceptaciones(0);
      final nivel2 = aceptaciones(2);
      final nivel5 = aceptaciones(5);

      expect(nivel2, greaterThanOrEqualTo(sinAbogado));
      expect(nivel5, greaterThanOrEqualTo(sinAbogado));
      expect(nivel5, greaterThanOrEqualTo(nivel2));
      expect(sinAbogado, 6); // 1,00–1,05
      expect(nivel2, 10); // 1,00–1,09
      expect(nivel5, 16); // 1,00–1,15
    });

    test('el abogado reduce la retirada al pedir más', () {
      expect(
        probabilidadRetiradaConAbogado(
          probabilidadBase: probRetiradaPedirMas,
          nivelAbogado: 0,
        ),
        closeTo(probRetiradaPedirMas, 1e-9),
      );
      expect(
        probabilidadRetiradaConAbogado(
          probabilidadBase: probRetiradaPedirMas,
          nivelAbogado: 5,
        ),
        closeTo(probRetiradaPedirMas * 0.75, 1e-9),
      );
    });
  });

  group('relaciones públicas', () {
    test('reduce reputación, moral y valor de mis representados', () {
      final mio = _jugador('mio');
      final ia = _jugador('ia', representadoPorMi: false);
      mio.valorMercado = valorMercadoDe(mio);
      ia.valorMercado = valorMercadoDe(ia);
      final estado = _estado(
        jugadores: [mio, ia],
        staff: [_staff(RolStaff.relacionesPublicas, 5)],
        reputacion: 50,
      );
      final contexto = ContextoEventos(
        estado: estado,
        indiceJugadores: {'mio': mio, 'ia': ia},
        indiceEquipos: {},
        rnd: Random(1),
        nuevoIdJugador: () => 'nuevo',
      );

      // Pérdida de 10 de moral: 10 × 0,25 = 2,5 → 3.
      contexto.cambiarMoral(mio, -10);
      expect(mio.moral, 67);
      // Un jugador de la IA no recibe la reducción.
      contexto.cambiarMoral(ia, -10);
      expect(ia.moral, 60);

      // Pérdida de 10 % de valor: 10 × 0,25 = 2,5 → 3.
      contexto.multiplicarValor(mio, 0.90);
      expect(mio.multiplicadorValor, closeTo(0.97, 1e-9));
      contexto.multiplicarValor(ia, 0.90);
      expect(ia.multiplicadorValor, closeTo(0.90, 1e-9));

      // Pérdida de 2 de reputación: 2 × 0,25 = 0,5 → 1 (nunca 0).
      contexto.cambiarReputacion(-2);
      expect(estado.agente.reputacion, 49);
      // Una pérdida de 1 se queda en 1 aunque la RP esté al máximo.
      contexto.cambiarReputacion(-1);
      expect(estado.agente.reputacion, 48);
      // Las ganancias no se reducen.
      contexto.cambiarReputacion(2);
      expect(estado.agente.reputacion, 50);
    });

    test('un evento resuelto dos veces no descuenta dos veces', () {
      final mio = _jugador('mio');
      mio.valorMercado = valorMercadoDe(mio);
      final estado = _estado(
        jugadores: [mio],
        staff: [_staff(RolStaff.relacionesPublicas, 5)],
        reputacion: 50,
      );
      final evento = _evento('polemica_redes', jugadorId: mio.id);
      estado.eventosPendientes.add(evento);

      final primero = _resolver(estado, evento, opcion: 1);
      expect(primero.noticia, isNotEmpty);
      expect(mio.moral, 67);
      expect(mio.multiplicadorValor, closeTo(0.97, 1e-9));
      expect(estado.agente.reputacion, 49);

      final segundo = _resolver(estado, evento, opcion: 1);
      expect(segundo.noticia, contains('ya no está disponible'));
      expect(mio.moral, 67);
      expect(mio.multiplicadorValor, closeTo(0.97, 1e-9));
      expect(estado.agente.reputacion, 49);
    });

    test('no reduce los costos en dinero de los eventos', () {
      final mio = _jugador('mio');
      final estado = _estado(
        jugadores: [mio],
        staff: [_staff(RolStaff.relacionesPublicas, 5)],
        dinero: 100000,
      );
      final evento = _evento(
        'polemica_redes',
        jugadorId: mio.id,
        costoBaseA: 10000,
      );
      estado.eventosPendientes.add(evento);

      _resolver(estado, evento, opcion: 0);
      expect(estado.agente.dinero, 90000);
      expect(mio.moral, 70);
    });

    test('rumor negativo sigue quitando 1 de reputación', () {
      final estado = _estado(
        staff: [_staff(RolStaff.relacionesPublicas, 5)],
        reputacion: 50,
      );
      final evento = _evento('rumor_negativo');
      estado.eventosPendientes.add(evento);

      _resolver(estado, evento);
      expect(estado.agente.reputacion, 49);
    });
  });

  group('preparador', () {
    test('solo aplica a mis representados y respeta el tope ×1,4', () {
      final mio = _jugador('mio');
      final ajeno = _jugador('ajeno', representadoPorMi: false);

      expect(
        multiplicadorProgresionPreparador(_estado(), mio),
        closeTo(1.0, 1e-9),
      );
      expect(
        multiplicadorProgresionPreparador(
          _estado(staff: [_staff(RolStaff.preparador, 1)]),
          mio,
        ),
        closeTo(1.08, 1e-9),
      );
      expect(
        multiplicadorProgresionPreparador(
          _estado(staff: [_staff(RolStaff.preparador, 5)]),
          mio,
        ),
        closeTo(1.4, 1e-9),
      );
      expect(
        multiplicadorProgresionPreparador(
          _estado(staff: [_staff(RolStaff.preparador, 5)]),
          ajeno,
        ),
        closeTo(1.0, 1e-9),
      );
      expect(
        multiplicadorProgresionPreparador(
          _estado(staff: [_staff(RolStaff.preparador, 5)]),
          mio,
          enAcademia: true,
        ),
        closeTo(1.0, 1e-9),
      );
    });

    test('multiplica la probabilidad de progresión juvenil', () {
      final joven = _jugador('joven', edad: 18, moral: 70);
      // 18 años → 10 %; sin equipo → ×0,5 = 5 %.
      expect(probabilidadProgresoSemanal(joven), closeTo(0.05, 1e-9));
      expect(
        probabilidadProgresoSemanal(joven, multiplicador: 1.4),
        closeTo(0.07, 1e-9),
      );
      // El tope se aplica aunque se pase un multiplicador mayor.
      expect(
        probabilidadProgresoSemanal(joven, multiplicador: 3.0),
        closeTo(0.07, 1e-9),
      );
    });

    test('en adultos inclina la balanza a la mejora sin aumentar bajadas', () {
      ({int subidas, int bajadas}) simular(int edad, double multiplicador) {
        final rnd = Random(20251019);
        var subidas = 0;
        var bajadas = 0;
        for (var i = 0; i < 4000; i++) {
          final jugador = _jugador(
            'p$i',
            edad: edad,
            habilidad: 50,
            potencial: 90,
          );
          final antes = jugador.habilidad;
          aplicarProgresoSemanal(
            jugador,
            rnd,
            multiplicadorProbabilidad: multiplicador,
          );
          if (jugador.habilidad > antes) subidas++;
          if (jugador.habilidad < antes) bajadas++;
        }
        return (subidas: subidas, bajadas: bajadas);
      }

      final adultoSin = simular(25, 1.0);
      final adultoCon = simular(25, 1.4);
      expect(adultoCon.subidas, greaterThan(adultoSin.subidas));
      expect(adultoCon.bajadas, lessThanOrEqualTo(adultoSin.bajadas));
      expect(
        adultoCon.subidas - adultoCon.bajadas,
        greaterThan(adultoSin.subidas - adultoSin.bajadas),
      );

      // A los 28+ solo existe la probabilidad de bajar: el preparador no la
      // toca y los resultados son idénticos con la misma semilla.
      final mayorSin = simular(30, 1.0);
      final mayorCon = simular(30, 1.4);
      expect(mayorSin.subidas, 0);
      expect(mayorCon.subidas, 0);
      expect(mayorCon.bajadas, mayorSin.bajadas);
    });
  });

  group('salarios y acciones', () {
    test('contratar entra siempre en nivel 1 y no cuesta dinero', () async {
      final motor = await crearPartidaSembrada(dinero: 100000);
      final dineroAntes = motor.agente.dinero;

      final resultado = await motor.contratarStaff(RolStaff.abogado);
      expect(resultado.ok, isTrue);
      expect(motor.staff, hasLength(1));
      expect(motor.staff.first.nivel, 1);
      expect(motor.agente.dinero, dineroAntes);
      expect(motor.gastoStaffSemanal, 80);
      expect(
        motor.gastoFijoSemanalTotal,
        gastoOficinaSemanal +
            motor.gastoOjeadoresSemanal +
            motor.gastoStaffSemanal +
            motor.gastoAcademiaSemanal,
      );

      // Máximo un miembro por rol: no se puede contratar dos abogados.
      final repetido = await motor.contratarStaff(RolStaff.abogado);
      expect(repetido.ok, isFalse);
      expect(motor.staff, hasLength(1));
    });

    test('mejorar cobra la diferencia de salario por 13 semanas', () async {
      final motor = await crearPartidaSembrada(dinero: 100000);
      await motor.contratarStaff(RolStaff.abogado);
      final miembro = motor.staff.first;
      final dineroAntes = motor.agente.dinero;

      final resultado = await motor.mejorarStaff(miembro);
      expect(resultado.ok, isTrue);
      expect(miembro.nivel, 2);
      expect(
        motor.agente.dinero,
        dineroAntes - (salarioStaff(2) - salarioStaff(1)) * 13,
      );
      expect(motor.gastoStaffSemanal, salarioStaff(2));

      // Se puede subir hasta 5 y no más.
      while (miembro.nivel < 5) {
        expect((await motor.mejorarStaff(miembro)).ok, isTrue);
      }
      expect(miembro.nivel, 5);
      expect((await motor.mejorarStaff(miembro)).ok, isFalse);
    });

    test(
      'el salario del staff se cobra cada semana y el despido lo corta',
      () async {
        final motor = await crearPartidaSembrada(dinero: 100000);
        await motor.contratarStaff(RolStaff.abogado);
        await motor.contratarStaff(RolStaff.relacionesPublicas);

        await motor.avanzarSemana();
        expect(
          motor.estado!.gastosUltimaSemana,
          gastoOficinaSemanal + salarioStaff(1) * 2,
        );

        final abogado = motor.miembroStaff(RolStaff.abogado)!;
        await motor.despedirStaff(abogado);
        await motor.avanzarSemana();
        expect(
          motor.estado!.gastosUltimaSemana,
          gastoOficinaSemanal + salarioStaff(1),
        );
      },
    );
  });
}
