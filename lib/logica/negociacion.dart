// Lógica de la negociación: cuando ofrezco a mi jugador a un equipo,
// el equipo decide si acepta, hace una contraoferta o rechaza.
import 'dart:math';

/// Las tres respuestas posibles de un equipo.
enum RespuestaEquipo {
  acepta,
  contraoferta,
  rechaza,
  sinInteres,
  sinPresupuesto,
}

/// Resultado de una oferta enviada a un equipo.
class ResultadoOferta {
  ResultadoOferta({
    required this.respuesta,
    required this.mensaje,
    this.contraoferta = 0,
  });

  final RespuestaEquipo respuesta;

  /// Texto que se muestra al usuario.
  final String mensaje;

  /// Si hay contraoferta, el precio que ofrece el equipo.
  final int contraoferta;
}

/// Límites de la negociación (ajustables).
/// Si pido hasta un 5% más del valor, el equipo acepta.
const double limiteAceptacion = 1.05;

/// Si pido entre 5% y 40% más del valor, el equipo contraoferta.
const double limiteContraoferta = 1.40;

/// Mínimo y máximo que ofrece el equipo en una contraoferta.
const double contraofertaMin = 0.85;
const double contraofertaMax = 1.00;

/// Calcula la respuesta del equipo a mi precio pedido.
///
/// [precioPedido] es lo que pido por el jugador.
/// [valorMercado] es el valor de mercado actual del jugador.
/// [rnd] es el generador de números aleatorios.
/// [margenExtraAceptacion] amplía el límite de aceptación (por ejemplo, el
/// contacto con un equipo grande de la Parte 2E suma 0,10).
ResultadoOferta calcularRespuesta({
  required int precioPedido,
  required int valorMercado,
  required Random rnd,
  double margenExtraAceptacion = 0,
}) {
  final limiteAceptacionActual = limiteAceptacion + margenExtraAceptacion;

  // Si el precio pedido no supera el límite de aceptación, el equipo acepta.
  if (precioPedido <= valorMercado * limiteAceptacionActual) {
    return ResultadoOferta(
      respuesta: RespuestaEquipo.acepta,
      mensaje: 'El equipo acepta tu oferta.',
    );
  }

  // Si supera la aceptación pero no llega a 1,40, el equipo contraoferta.
  if (precioPedido <= valorMercado * limiteContraoferta) {
    final factor =
        contraofertaMin +
        rnd.nextDouble() * (contraofertaMax - contraofertaMin);
    final oferta = (valorMercado * factor).round();
    return ResultadoOferta(
      respuesta: RespuestaEquipo.contraoferta,
      mensaje: 'El equipo no acepta ese precio, pero ofrece menos.',
      contraoferta: oferta,
    );
  }

  // Si pido más del 40%, rechaza directamente.
  return ResultadoOferta(
    respuesta: RespuestaEquipo.rechaza,
    mensaje: 'El equipo rechaza tu oferta por ser demasiado alta.',
  );
}
