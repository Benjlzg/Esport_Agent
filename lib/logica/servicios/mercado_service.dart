// Servicio de mercado y negociación (corrección I11).
//
// Reúne las acciones del agente (reclutar, ofrecer, aceptar ofertas), el
// mercado automático de la IA y la gestión de ofertas. `MotorJuego` conserva
// los mismos métodos públicos y delega aquí, así que las pantallas no cambian.
import 'dart:math';

import '../../modelos/equipo.dart';
import '../../modelos/estado_partida.dart';
import '../../modelos/jugador.dart';
import '../../modelos/noticia.dart';
import '../../modelos/oferta.dart';
import '../calendario.dart';
import '../eventos.dart' as eventos;
import '../formulas.dart';
import '../mercado.dart' as mercado;
import '../negociacion.dart';
import '../renovaciones.dart' as renovaciones;
import '../motor_juego.dart';

/// Acciones de mercado del motor.
class MercadoService {
  MercadoService(this.motor);

  final MotorJuego motor;

  /// Recluta (representa) a un jugador. Cobra el 5 % de su valor.
  Future<ResultadoAccion> reclutar(Jugador jugador) async {
    final ag = motor.agente;
    if (jugador.representadoPorMi) {
      return ResultadoAccion(false, 'Ya representas a ${jugador.nick}.');
    }
    if (!aceptaRepresentacion(
      reputacion: ag.reputacion,
      habilidad: jugador.habilidad,
    )) {
      return ResultadoAccion(
        false,
        '${jugador.nick} prefiere un agente con más prestigio.',
      );
    }
    final costo = costoRepresentar(jugador.valorMercado);
    if (ag.dinero < costo) {
      return ResultadoAccion(
        false,
        'No tienes dinero suficiente (necesitas ${formatearDinero(costo)}).',
      );
    }
    ag.dinero -= costo;
    jugador.representadoPorMi = true;
    // El periodo mínimo de representación empieza de cero (corrección I1).
    jugador.semanasRepresentado = 0;
    motor.indices.actualizar(jugador);
    motor.agregarNoticia(
      'Reclutaste a ${jugador.nick} por ${formatearDinero(costo)}.',
      TipoNoticia.fichaje,
    );
    await motor.guardarYNotificar();
    return ResultadoAccion(true, 'Ahora representas a ${jugador.nick}.');
  }

  /// Deja de representar a un jugador.
  Future<ResultadoAccion> dejarDeRepresentar(Jugador jugador) async {
    jugador.representadoPorMi = false;
    jugador.semanasRepresentado = 0;
    motor.indices.actualizar(jugador);
    // Las ofertas pendientes por este jugador dejan de tener sentido (I6).
    invalidarOfertasObsoletas();
    motor.agregarNoticia(
      'Dejaste de representar a ${jugador.nick}.',
      TipoNoticia.evento,
    );
    await motor.guardarYNotificar();
    return ResultadoAccion(true, 'Ya no representas a ${jugador.nick}.');
  }

  /// Calcula el interés de un equipo por un jugador.
  NivelInteres interesDe(Jugador jugador, Equipo equipo) {
    if (!equipoInteresado(
      habilidad: jugador.habilidad,
      prestigio: equipo.prestigio,
    )) {
      return NivelInteres.sinInteres;
    }
    if (jugador.habilidad >= equipo.prestigio) {
      return NivelInteres.muyInteresado;
    }
    return NivelInteres.interesado;
  }

  /// Rondas de negociación que quedan entre un jugador y un equipo.
  int rondasRestantes(Jugador jugador, Equipo equipo) {
    final clave = EstadoPartida.clavePar(jugador.id, equipo.id);
    final usadas = motor.estado!.rondasNegociacion[clave] ?? 0;
    return maxRondasNegociacion - usadas;
  }

  /// ¿Está bloqueado el par jugador+equipo hasta la próxima temporada?
  bool bloqueado(Jugador jugador, Equipo equipo) {
    final clave = EstadoPartida.clavePar(jugador.id, equipo.id);
    return motor.estado!.paresBloqueados.contains(clave);
  }

  /// Envía una oferta de un jugador a un equipo.
  Future<ResultadoOferta> ofrecer({
    required Jugador jugador,
    required Equipo equipo,
    required int precioPedido,
  }) async {
    final est = motor.estado!;
    if (!jugador.representadoPorMi) {
      return ResultadoOferta(
        respuesta: RespuestaEquipo.rechaza,
        mensaje: 'Solo puedes ofrecer jugadores de tu agencia.',
      );
    }
    // Debes representarlo un tiempo mínimo antes de ofrecerlo (I1): así no
    // se puede reclutar y revender en la misma semana para cobrar comisión.
    if (jugador.semanasRepresentado < semanasMinimasRepresentacion) {
      final faltan = semanasMinimasRepresentacion - jugador.semanasRepresentado;
      return ResultadoOferta(
        respuesta: RespuestaEquipo.sinInteres,
        mensaje:
            'Aún no puedes ofrecer a ${jugador.nick}: llevas '
            '${jugador.semanasRepresentado} de $semanasMinimasRepresentacion '
            'semanas como su agente. Espera $faltan semana'
            '${faltan == 1 ? '' : 's'}.',
      );
    }
    if (jugador.juego != equipo.juego) {
      return ResultadoOferta(
        respuesta: RespuestaEquipo.sinInteres,
        mensaje: 'El jugador y el equipo deben ser del mismo videojuego.',
      );
    }
    // No tiene sentido "vender" a un jugador a su propio club: generaría una
    // comisión y reputación sin ningún traspaso real (C6).
    if (jugador.equipoId == equipo.id) {
      return ResultadoOferta(
        respuesta: RespuestaEquipo.sinInteres,
        mensaje:
            '${equipo.nombre} ya tiene a ${jugador.nick}: no puedes venderlo '
            'a su propio club.',
      );
    }
    // Un jugador recién traspasado no puede volver a venderse hasta la
    // próxima temporada (corrección 2.5 A2).
    if (jugador.bloqueadoTraspaso(est.temporada)) {
      return ResultadoOferta(
        respuesta: RespuestaEquipo.sinInteres,
        mensaje:
            '${jugador.nick} acaba de cambiar de equipo: podrá negociar de '
            'nuevo la próxima temporada.',
      );
    }
    final clave = EstadoPartida.clavePar(jugador.id, equipo.id);
    if (est.paresBloqueados.contains(clave)) {
      return ResultadoOferta(
        respuesta: RespuestaEquipo.sinInteres,
        mensaje:
            '${equipo.nombre} ya no quiere negociar hasta la próxima temporada.',
      );
    }
    if (rondasRestantes(jugador, equipo) <= 0) {
      est.paresBloqueados.add(clave);
      await motor.guardarYNotificar();
      return ResultadoOferta(
        respuesta: RespuestaEquipo.sinInteres,
        mensaje: 'Se acabaron las rondas con ${equipo.nombre}.',
      );
    }
    if (!equipoInteresado(
      habilidad: jugador.habilidad,
      prestigio: equipo.prestigio,
    )) {
      return ResultadoOferta(
        respuesta: RespuestaEquipo.sinInteres,
        mensaje: '${equipo.nombre} no está interesado en ${jugador.nick}.',
      );
    }
    if (jugador.valorMercado > equipo.presupuesto) {
      return ResultadoOferta(
        respuesta: RespuestaEquipo.sinPresupuesto,
        mensaje: '${equipo.nombre} no tiene presupuesto suficiente.',
      );
    }

    // Consumo una ronda de negociación.
    est.rondasNegociacion[clave] = (est.rondasNegociacion[clave] ?? 0) + 1;

    // El contacto con un equipo grande da más margen solo en equipos de élite.
    final margenContacto =
        est.semanasContactoGrande > 0 && equipo.prestigio >= 85
        ? eventos.margenContactoGrande
        : 0.0;

    final resultado = calcularRespuesta(
      precioPedido: precioPedido,
      valorMercado: jugador.valorMercado,
      rnd: motor.rnd,
      margenExtraAceptacion: margenContacto,
    );

    if (resultado.respuesta == RespuestaEquipo.acepta) {
      // Validación final antes de mover dinero: el comprador debe poder pagar
      // el precio aceptado y el jugador debe seguir en su club (C4/C6).
      final motivo = _motivoTraspasoInvalido(
        jugador: jugador,
        equipo: equipo,
        precio: precioPedido,
        // `ofrecer` ya se usa desde la pantalla, que controla la ventana.
        // Aquí solo se valida el dinero y la situación del jugador.
        comprobarVentana: false,
      );
      if (motivo != null) {
        return ResultadoOferta(
          respuesta: RespuestaEquipo.sinPresupuesto,
          mensaje: motivo,
        );
      }
      await _cerrarTrato(jugador, equipo, precioPedido);
    } else {
      if (resultado.respuesta == RespuestaEquipo.rechaza &&
          rondasRestantes(jugador, equipo) <= 0) {
        est.paresBloqueados.add(clave);
      }
      await motor.guardarYNotificar();
    }
    return resultado;
  }

  /// Acepta una contraoferta del equipo y cierra el trato.
  Future<ResultadoAccion> aceptarContraoferta({
    required Jugador jugador,
    required Equipo equipo,
    required int precio,
  }) async {
    // Las mismas reglas que al aceptar una oferta entrante (C4/C6): el
    // jugador debe seguir siendo mío, no puede irse a su propio club y el
    // comprador debe poder pagar.
    final motivo = _motivoTraspasoInvalido(
      jugador: jugador,
      equipo: equipo,
      precio: precio,
    );
    if (motivo != null) return ResultadoAccion(false, motivo);
    await _cerrarTrato(jugador, equipo, precio);
    return ResultadoAccion(true, 'Trato cerrado con ${equipo.nombre}.');
  }

  /// Devuelve el motivo por el que un traspaso ya no se puede cerrar, o null
  /// si es válido. Centraliza las comprobaciones de C4 y C6.
  String? _motivoTraspasoInvalido({
    Oferta? oferta,
    required Jugador jugador,
    required Equipo equipo,
    required int precio,
    bool comprobarVentana = true,
  }) {
    final est = motor.estado!;
    if (oferta != null && !est.ofertas.contains(oferta)) {
      return 'La oferta ya no está disponible.';
    }
    if (!jugador.representadoPorMi) {
      return 'Ya no representas a ${jugador.nick}.';
    }
    if (equipo.id == jugador.equipoId) {
      return '${equipo.nombre} ya tiene a ${jugador.nick}: no puedes venderlo '
          'a su propio club.';
    }
    if (equipo.juego != jugador.juego) {
      return 'El jugador y el equipo deben ser del mismo videojuego.';
    }
    final origen = oferta?.equipoOrigenId;
    if (origen != null && jugador.equipoId != origen) {
      return '${jugador.nick} ya no está en el club de origen de la oferta.';
    }
    if (comprobarVentana &&
        jugador.equipoId != null &&
        !enVentanaFichajes(est.semana)) {
      return 'El mercado está cerrado. ${proximaVentanaTexto(est.semana)}';
    }
    if (jugador.bloqueadoTraspaso(est.temporada)) {
      return '${jugador.nick} acaba de cambiar de equipo: podrá negociar de '
          'nuevo la próxima temporada.';
    }
    if (precio <= 0) {
      return 'El importe de la oferta no es válido.';
    }
    if (equipo.presupuesto < precio) {
      return '${equipo.nombre} no tiene presupuesto suficiente para pagar '
          '${formatearDinero(precio)}.';
    }
    return null;
  }

  /// Cierra la transferencia: paga la comisión, actualiza el equipo, etc.
  Future<void> _cerrarTrato(
    Jugador jugador,
    Equipo equipo,
    int precio, {
    int? salarioAnual,
  }) async {
    final est = motor.estado!;
    final ag = motor.agente;
    final origenId = jugador.equipoId;

    // El club vendedor recibe el precio menos la comisión del agente (I2).
    final comisionBruta = comisionPorTransferencia(precio);
    var vendedor = origenId == null ? null : motor.indices.equipos[origenId];
    if (vendedor == null && origenId != null) {
      for (final posible in est.equipos) {
        if (posible.id == origenId) {
          vendedor = posible;
          break;
        }
      }
    }
    if (vendedor != null && vendedor.id != equipo.id) {
      vendedor.presupuesto += precio - comisionBruta;
    }

    // El jugador desplazado en ese rol baja a suplente (no queda libre).
    for (final otro in est.jugadores) {
      if (otro.id != jugador.id &&
          otro.equipoId == equipo.id &&
          otro.rol == jugador.rol &&
          !otro.suplente) {
        otro.suplente = true;
        motor.indices.actualizar(otro);
        motor.agregarNoticia(
          '${otro.nick} pasa a suplente tras la llegada de ${jugador.nick} a ${equipo.nombre}.',
          TipoNoticia.evento,
        );
      }
    }
    // Si el equipo supera el máximo de suplentes, el más débil queda libre.
    for (final sobrante in mercado.recortarSuplentes(est, equipo)) {
      motor.indices.actualizar(sobrante);
      motor.agregarNoticia(
        '${sobrante.nick} quedó libre para hacer sitio en ${equipo.nombre}.',
        TipoNoticia.evento,
      );
    }

    final comision = motor.comisionNeta(comisionPorTransferencia(precio));
    ag.dinero += comision;
    // La validación previa garantiza que el comprador tiene este dinero.
    equipo.presupuesto -= precio;

    jugador.equipoId = equipo.id;
    jugador.suplente = false;
    jugador.semanasContrato = 52 + motor.rnd.nextInt(53);
    jugador.semanasComoSuplente = 0;
    // El salario prometido en la oferta se aplica de verdad (I7).
    jugador.salarioAnual =
        salarioAnual ?? calcularSalarioAnual(jugador.valorMercado);
    // Queda bloqueado para otro traspaso hasta la próxima temporada.
    jugador.temporadaUltimoTraspaso = est.temporada;
    motor.indices.actualizar(jugador);

    // Reputación: cada traspaso cerrado suma. Un equipo de élite
    // (prestigio ≥ 85) da más visibilidad que uno normal.
    final reputacionGanada = reputacionPorTraspaso(
      reputacionActual: ag.reputacion,
      elite: equipo.prestigio >= 85,
    );
    ag.reputacion = min(100, ag.reputacion + reputacionGanada);

    motor.agregarNoticia(
      '${jugador.nick} fue transferido a ${equipo.nombre} por ${formatearDinero(precio)}. '
      'Tu comisión: ${formatearDinero(comision)}.',
      TipoNoticia.venta,
    );

    // Si el equipo de origen se queda sin titular en ese rol, se repone.
    if (origenId != null && origenId != equipo.id) {
      motor.reponerTitular(origenId, jugador.rol);
    }

    final clave = EstadoPartida.clavePar(jugador.id, equipo.id);
    est.rondasNegociacion.remove(clave);
    // Cualquier otra oferta por este jugador quedó obsoleta al cambiar de
    // club (corrección I6).
    invalidarOfertasObsoletas();
    await motor.guardarYNotificar();
  }

  /// Quita las ofertas que ya no representan la situación actual del jugador.
  void invalidarOfertasObsoletas() {
    final est = motor.estado!;
    // Algunas pruebas (y partidas restauradas a mano) asignan `estado` sin
    // pasar por `cargar`. Si los índices están vacíos, se reconstruyen para
    // no borrar ofertas válidas por error.
    motor.asegurarIndices();
    est.ofertas.removeWhere((oferta) {
      final jugador = motor.indices.jugadores[oferta.jugadorId];
      if (jugador == null) return true;
      if (!jugador.representadoPorMi) return true;
      final equipo = motor.indices.equipos[oferta.equipoId];
      if (equipo == null) return true;

      if (oferta.tipo == TipoOferta.renovacion) {
        return jugador.equipoId != oferta.equipoId ||
            jugador.semanasContrato <= 0;
      }

      if (equipo.id == jugador.equipoId) return true;
      if (equipo.juego != jugador.juego) return true;
      final origen = oferta.equipoOrigenId;
      if (origen != null && jugador.equipoId != origen) return true;
      if (equipo.presupuesto < oferta.monto) return true;
      // Recién traspasado: la oferta nació antes de ese cambio o ya no vale.
      if (jugador.bloqueadoTraspaso(est.temporada)) return true;
      return false;
    });
  }

  /// Procesa los fichajes automáticos de la IA en la semana actual.
  void procesarSemanaIA() {
    final est = motor.estado!;
    final resultado = mercado.procesarMercadoIA(
      estado: est,
      indiceEquipos: motor.indices.equipos,
      indiceJugadores: motor.indices.jugadores,
      rnd: motor.rnd,
      nuevoIdJugador: motor.nuevoId,
    );
    motor.metricas.fichajesIA += resultado.fichajesCerrados;
    motor.metricas.fichajesVentana += resultado.fichajesCerrados;
    motor.metricas.ofertasIA += resultado.ofertas.length;
    motor.metricas.ofertasVentana += resultado.ofertas.length;
    for (final texto in resultado.noticias) {
      motor.agregarNoticia(texto, TipoNoticia.fichaje);
    }
    for (final oferta in resultado.ofertas) {
      final jugador = motor.indices.jugadores[oferta.jugadorId];
      final equipo = motor.indices.equipos[oferta.equipoId];
      if (jugador != null && equipo != null) {
        motor.agregarNoticia(
          '${equipo.nombre} ofrece ${formatearDinero(oferta.monto)} por ${jugador.nick}.',
          TipoNoticia.venta,
        );
      }
    }
    // El mercado pudo cambiar jugadores de equipo: los índices de plantilla y
    // de representados se actualizan una vez al final (I9).
    motor.reconstruirIndices();
  }

  /// Revisa las renovaciones (todas las semanas).
  void procesarRenovaciones() {
    final est = motor.estado!;
    final ofertas = renovaciones.generarRenovaciones(
      estado: est,
      indiceEquipos: motor.indices.equipos,
      rnd: motor.rnd,
    );
    for (final oferta in ofertas) {
      final jugador = motor.indices.jugadores[oferta.jugadorId];
      final equipo = motor.indices.equipos[oferta.equipoId];
      if (jugador != null && equipo != null) {
        motor.agregarNoticia(
          '${equipo.nombre} quiere renovar a ${jugador.nick} '
          '(nuevo salario ${formatearDinero(oferta.monto)}).',
          TipoNoticia.evento,
        );
      }
    }
    renovaciones.renovacionesAutomaticasIA(estado: est, rnd: motor.rnd);
  }

  /// Baja las semanas de las ofertas de traspaso y elimina las vencidas.
  void avanzarOfertas() {
    final est = motor.estado!;
    final vencidas = <Oferta>[];
    final invalidas = <Oferta>[];
    for (final oferta in est.ofertas) {
      if (oferta.tipo == TipoOferta.traspaso) {
        // Una oferta creada esta misma semana no descuenta tiempo todavía:
        // así el agente dispone de las 2 semanas que se le prometen.
        final recienCreada =
            oferta.temporada == est.temporada && oferta.semana == est.semana;
        if (recienCreada) continue;
        oferta.semanasRestantes--;
        if (oferta.semanasRestantes <= 0) vencidas.add(oferta);
      } else {
        final jugador = motor.indices.jugadores[oferta.jugadorId];
        final vigente =
            jugador != null &&
            jugador.equipoId == oferta.equipoId &&
            jugador.semanasContrato > 0;
        if (!vigente) invalidas.add(oferta);
      }
    }
    est.ofertas.removeWhere(
      (o) => vencidas.contains(o) || invalidas.contains(o),
    );
    // Además, cualquier oferta que haya quedado obsoleta por un cambio de
    // club, de videojuego, de agencia o de presupuesto se elimina (I6).
    invalidarOfertasObsoletas();
    for (final oferta in vencidas) {
      final jugador = motor.indices.jugadores[oferta.jugadorId];
      if (jugador != null) {
        motor.agregarNoticia(
          'La oferta por ${jugador.nick} venció sin respuesta.',
          TipoNoticia.alerta,
        );
      }
    }
  }

  /// Acepta una oferta: cierra el traspaso o aplica la renovación.
  Future<ResultadoAccion> aceptarOferta(Oferta oferta) async {
    final est = motor.estado!;
    // La oferta debe seguir pendiente. Esto también evita que un doble toque
    // en "Aceptar" cobre dos comisiones por la misma renovación (C4).
    if (!est.ofertas.contains(oferta)) {
      return ResultadoAccion(false, 'La oferta ya no está disponible.');
    }
    final jugador = motor.indices.jugadores[oferta.jugadorId];
    final equipo = motor.indices.equipos[oferta.equipoId];
    if (jugador == null || equipo == null) {
      est.ofertas.remove(oferta);
      await motor.guardarYNotificar();
      return ResultadoAccion(false, 'La oferta ya no es válida.');
    }
    if (oferta.tipo == TipoOferta.traspaso) {
      final motivo = _motivoTraspasoInvalido(
        oferta: oferta,
        jugador: jugador,
        equipo: equipo,
        precio: oferta.monto,
      );
      if (motivo != null) {
        est.ofertas.remove(oferta);
        await motor.guardarYNotificar();
        return ResultadoAccion(false, motivo);
      }
      await _cerrarTrato(
        jugador,
        equipo,
        oferta.monto,
        salarioAnual: oferta.salarioAnual,
      );
      est.ofertas.remove(oferta);
      await motor.guardarYNotificar();
      return ResultadoAccion(
        true,
        'Aceptaste vender a ${jugador.nick} a ${equipo.nombre}.',
      );
    }

    // Renovación de contrato: el jugador debe seguir representado y en el
    // mismo club, con contrato vigente.
    if (!jugador.representadoPorMi ||
        jugador.equipoId != oferta.equipoId ||
        jugador.semanasContrato <= 0) {
      est.ofertas.remove(oferta);
      await motor.guardarYNotificar();
      return ResultadoAccion(false, 'La oferta de renovación ya no es válida.');
    }
    jugador.salarioAnual = oferta.monto;
    jugador.semanasContrato = 52 + motor.rnd.nextInt(53);
    final comision = motor.comisionNeta(
      (oferta.monto * comisionRenovacion).round(),
    );
    motor.agente.dinero += comision;
    est.ofertas.remove(oferta);
    motor.agregarNoticia(
      'Renovaste a ${jugador.nick} con ${equipo.nombre}. '
      'Tu comisión: ${formatearDinero(comision)}.',
      TipoNoticia.venta,
    );
    await motor.guardarYNotificar();
    return ResultadoAccion(true, 'Renovación aceptada.');
  }

  /// Rechaza una oferta. Si era de renovación, el jugador quedará libre.
  Future<ResultadoAccion> rechazarOferta(Oferta oferta) async {
    final est = motor.estado!;
    if (!est.ofertas.contains(oferta)) {
      return ResultadoAccion(false, 'La oferta ya no está disponible.');
    }
    final jugador = motor.indices.jugadores[oferta.jugadorId];
    final equipo = motor.indices.equipos[oferta.equipoId];
    est.ofertas.remove(oferta);
    if (jugador != null && equipo != null) {
      if (oferta.tipo == TipoOferta.renovacion) {
        motor.agregarNoticia(
          'Rechazaste la renovación de ${equipo.nombre} para ${jugador.nick}; '
          'quedará libre al terminar su contrato.',
          TipoNoticia.alerta,
        );
      } else {
        motor.agregarNoticia(
          'Rechazaste la oferta de ${equipo.nombre} por ${jugador.nick}.',
          TipoNoticia.evento,
        );
      }
    }
    await motor.guardarYNotificar();
    return ResultadoAccion(true, 'Oferta rechazada.');
  }

  /// Pide más dinero por una oferta de traspaso. El equipo puede subirla o
  /// retirarla, pero hay un máximo de mejoras y un tope de importe (C5).
  Future<ResultadoAccion> pedirMasOferta(Oferta oferta) async {
    final est = motor.estado!;
    if (!est.ofertas.contains(oferta)) {
      return ResultadoAccion(false, 'La oferta ya no está disponible.');
    }
    if (oferta.tipo != TipoOferta.traspaso) {
      return ResultadoAccion(
        false,
        'Solo puedes pedir más en una oferta de traspaso.',
      );
    }
    final jugador = motor.indices.jugadores[oferta.jugadorId];
    final equipo = motor.indices.equipos[oferta.equipoId];
    if (jugador == null || equipo == null) {
      est.ofertas.remove(oferta);
      await motor.guardarYNotificar();
      return ResultadoAccion(false, 'La oferta ya no es válida.');
    }

    // Oferta obsoleta: el jugador cambió de club, dejó de ser mío o el
    // comprador ya no puede pagar. No se mejora una oferta irreal (C4).
    final origen = oferta.equipoOrigenId;
    final obsoleta =
        !jugador.representadoPorMi ||
        equipo.id == jugador.equipoId ||
        equipo.juego != jugador.juego ||
        (origen != null && jugador.equipoId != origen) ||
        jugador.bloqueadoTraspaso(est.temporada);
    if (obsoleta) {
      est.ofertas.remove(oferta);
      await motor.guardarYNotificar();
      return ResultadoAccion(false, 'La oferta ya no es válida.');
    }

    // Tope de mejoras: después de dos subidas el equipo ya no ofrece más y
    // la oferta mantiene su plazo original.
    if (oferta.mejorasRealizadas >= maxMejorasOferta) {
      return ResultadoAccion(
        false,
        '${equipo.nombre} ya no mejorará más su oferta por ${jugador.nick}.',
      );
    }

    if (motor.rnd.nextDouble() < probRetiradaPedirMas) {
      est.ofertas.remove(oferta);
      motor.agregarNoticia(
        '${equipo.nombre} retiró su oferta por ${jugador.nick}.',
        TipoNoticia.alerta,
      );
      await motor.guardarYNotificar();
      return ResultadoAccion(true, '${equipo.nombre} retiró la oferta.');
    }

    // El tope no puede superar ni el 140 % del valor ni el presupuesto del
    // comprador. Si una oferta vieja no lo guardó, se calcula ahora.
    final topeGuardado = oferta.montoMaximo > 0
        ? oferta.montoMaximo
        : topeMontoOferta(
            valorMercado: jugador.valorMercado,
            presupuesto: equipo.presupuesto,
          );
    final tope = min(topeGuardado, equipo.presupuesto);
    final factor =
        1 + pedirMasMin + motor.rnd.nextDouble() * (pedirMasMax - pedirMasMin);
    final propuesto = ((oferta.monto * factor) / 1000).round() * 1000;
    final nuevoMonto = min(propuesto, tope);
    if (nuevoMonto <= oferta.monto) {
      return ResultadoAccion(
        false,
        '${equipo.nombre} no puede subir más la oferta por ${jugador.nick}.',
      );
    }

    oferta.monto = nuevoMonto;
    oferta.mejorasRealizadas++;
    // No se reinicia `semanasRestantes`: la oferta conserva su plazo real.
    motor.agregarNoticia(
      '${equipo.nombre} sube su oferta por ${jugador.nick} a ${formatearDinero(oferta.monto)}.',
      TipoNoticia.evento,
    );
    await motor.guardarYNotificar();
    return ResultadoAccion(
      true,
      'Nueva oferta: ${formatearDinero(oferta.monto)}.',
    );
  }
}
