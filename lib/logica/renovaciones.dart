// Renovaciones de contrato (Parte 2D). A diferencia de los traspasos, las
// renovaciones se revisan TODAS las semanas, no solo en ventana de fichajes.
import 'dart:math';

import '../modelos/equipo.dart';
import '../modelos/estado_partida.dart';
import '../modelos/oferta.dart';
import 'formulas.dart';

/// Habilidad a partir de la cual un equipo renueva solo a un jugador ajeno
/// aunque no haya jugado (por debajo, necesita buena nota).
const int habilidadRenovacionAutomatica = 75;

/// Genera ofertas de renovación para mis jugadores. Su equipo les ofrece
/// renovar si les queda poco contrato, con más probabilidad si su nota
/// promedio es buena (≥6).
List<Oferta> generarRenovaciones({
  required EstadoPartida estado,
  required Map<String, Equipo> indiceEquipos,
  required Random rnd,
}) {
  final ofertas = <Oferta>[];
  for (final j in estado.jugadores) {
    if (!j.representadoPorMi) continue;
    if (j.equipoId == null) continue;
    if (j.semanasContrato > umbralSemanasRenovacion) continue;
    // No duplicar si ya hay una renovación pendiente para el jugador.
    if (estado.ofertas.any(
      (o) => o.tipo == TipoOferta.renovacion && o.jugadorId == j.id,
    )) {
      continue;
    }

    final probabilidad = j.promedioNota >= 6
        ? probRenovacionBuena
        : probRenovacionMala;
    if (rnd.nextDouble() >= probabilidad) continue;

    final nuevoSalario = max(
      j.salarioAnual,
      calcularSalarioAnual(valorMercadoDe(j)),
    );
    final oferta = Oferta(
      id: 'of_${j.id}_${j.equipoId}_${estado.temporada}_${estado.semana}',
      tipo: TipoOferta.renovacion,
      jugadorId: j.id,
      equipoId: j.equipoId!,
      monto: nuevoSalario,
      salarioAnual: nuevoSalario,
      semanasRestantes: umbralSemanasRenovacion,
      temporada: estado.temporada,
      semana: estado.semana,
    );
    ofertas.add(oferta);
    estado.ofertas.add(oferta);
  }
  return ofertas;
}

/// Renovaciones automáticas de los equipos para jugadores ajenos. Los
/// titulares buenos (nota ≥6 o habilidad alta) renuevan; los demás no, y
/// quedarán libres al llegar su contrato a 0.
List<String> renovacionesAutomaticasIA({
  required EstadoPartida estado,
  required Random rnd,
}) {
  final noticias = <String>[];
  for (final j in estado.jugadores) {
    if (j.representadoPorMi) continue;
    if (j.equipoId == null) continue;
    if (j.semanasContrato > umbralSemanasRenovacion) continue;

    final bueno =
        j.promedioNota >= 6 || j.habilidad >= habilidadRenovacionAutomatica;
    if (!bueno) continue;

    j.semanasContrato = 52 + rnd.nextInt(53);
    j.salarioAnual = max(
      j.salarioAnual,
      calcularSalarioAnual(valorMercadoDe(j)),
    );
  }
  return noticias;
}
