// Servicio de temporada (corrección I11): avance semanal, contratos,
// progresión, suplentes, cambio de temporada, ascensos, retiradas y jóvenes.
import 'dart:math';

import '../../modelos/estado_partida.dart';
import '../../modelos/historial.dart';
import '../../modelos/juego.dart';
import '../../modelos/jugador.dart';
import '../../modelos/noticia.dart';
import '../ascensos.dart';
import '../calendario.dart';
import '../formulas.dart';
import '../generador_jugadores.dart';
import '../mantenimiento.dart';
import '../mercado.dart' as mercado;
import '../motor_juego.dart';
import '../progresion.dart';

/// Orquesta el paso del tiempo y la evolución de los jugadores.
class TemporadaService {
  TemporadaService(this.motor);

  final MotorJuego motor;

  /// Cuerpo real del avance de semana, sin el bloqueo de doble toque.
  Future<void> avanzarSemanaInterna() async {
    final est = motor.estado!;
    final ag = est.agente;
    var ingresos = 0;
    var gastos = 0;

    // Los contadores de simulación se reinician al cambiar de temporada o de
    // ventana de fichajes. No forman parte del guardado.
    motor.metricas.asegurarTemporada(est.temporada);
    if (est.semana == 1 || est.semana == 23 || est.semana == 47) {
      motor.metricas.reiniciarVentana();
    }

    // 0) Antes de avanzar, se simula la etapa de esta semana.
    motor.competicionService.simularEtapaActual();

    // 1) Mercado y renovaciones. Las renovaciones se revisan TODAS las
    //    semanas; los traspasos de la IA solo en ventana de fichajes.
    if (enVentanaFichajes(est.semana)) {
      motor.mercadoService.procesarSemanaIA();
    }
    motor.mercadoService.procesarRenovaciones();

    // 2) Bajan las semanas de las ofertas pendientes (y vencen).
    motor.mercadoService.avanzarOfertas();

    // 3) Contadores de suplentes y castigo al terminar cada split.
    _actualizarContadoresSuplentes();
    if (est.semana == 18 || est.semana == 40) {
      _castigarSuplentesDeSplit();
    }

    // Cada 4 semanas, el valor de cada jugador sube o baja según su nota.
    if (est.semana % 4 == 0) {
      _ajustarValoresPorNota();
    }

    // 4) Una sola pasada por todos los jugadores (A3): comisión de salario,
    //    contrato, progreso e inactividad.
    gastos += gastoOficinaSemanal;
    final huecosPorContrato = <({String equipoId, String rol})>[];
    for (final j in est.jugadores) {
      // 4.0) Suma una semana de representación (corrección I1).
      if (j.representadoPorMi) j.semanasRepresentado++;

      // 4.1) Comisión por el salario de mis jugadores con equipo.
      if (j.representadoPorMi && j.equipoId != null) {
        final semanal = calcularSalarioSemanal(j.salarioAnual);
        ingresos += motor.comisionNeta((semanal * comisionSalario).round());
      }

      // 4.2) Baja el contrato; si llega a 0, el jugador queda libre.
      if (j.equipoId != null && j.semanasContrato > 0) {
        j.semanasContrato--;
        if (j.semanasContrato <= 0) {
          final equipoId = j.equipoId!;
          final rol = j.rol;
          final eraTitular = !j.suplente;
          j.equipoId = null;
          j.semanasContrato = 0;
          j.suplente = false;
          j.semanasComoSuplente = 0;
          motor.indices.actualizar(j);
          motor.agregarNoticia(
            '${j.nick} quedó libre al terminar su contrato.',
            TipoNoticia.alerta,
          );
          // Si se va un titular, el equipo repone su rol en la misma semana.
          if (eraTitular) {
            huecosPorContrato.add((equipoId: equipoId, rol: rol));
          }
        }
      }

      // 4.3) Progreso semanal (mejora o empeora la habilidad).
      _progresarJugador(j);

      // 4.4) Baja la semana de inactividad (lesión o descanso).
      if (j.semanasInactivo > 0) j.semanasInactivo--;
    }
    for (final hueco in huecosPorContrato) {
      motor.reponerTitular(hueco.equipoId, hueco.rol);
    }

    // 8) Avanza la semana y, si toca, empieza una nueva temporada.
    est.semana++;
    // Al empezar un split se reorganizan titulares y suplentes.
    if (est.semana == 5 || est.semana == 27) {
      _reorganizarTitulares();
    }
    // Al empezar una nueva ventana se resetea el contador de fichajes.
    if (est.semana == 23 || est.semana == 47) {
      est.fichajesVentana.clear();
    }
    if (est.semana == 47) {
      motor.competicionService.calcularPremiosTemporada();
    }
    if (est.semana > semanasPorTemporada) {
      _nuevaTemporada();
    }

    // 9) Aplico el dinero.
    ag.dinero += ingresos - gastos;

    // 10) Control de bancarrota.
    if (ag.dinero < 0) {
      ag.semanasEnNegativo++;
      if (ag.semanasEnNegativo >= semanasParaBancarrota) {
        est.finDelJuego = true;
        motor.agregarNoticia(
          '¡Bancarrota! Tu agencia no puede seguir funcionando.',
          TipoNoticia.alerta,
        );
      } else {
        motor.agregarNoticia(
          'Estás en números rojos (semana ${ag.semanasEnNegativo} de $semanasParaBancarrota).',
          TipoNoticia.alerta,
        );
      }
    } else {
      ag.semanasEnNegativo = 0;
    }

    // 11) Recalculo los valores de mercado.
    recalcularValores();

    // 12) Bajan los temporizadores después de que la semana los haya usado.
    //     La inactividad de los jugadores ya bajó en la pasada del paso 4.
    if (est.semanasInversor > 0) est.semanasInversor--;
    if (est.semanasContactoGrande > 0) est.semanasContactoGrande--;

    // 13) Eventos aleatorios de la semana (salvo si la partida terminó).
    if (!est.finDelJuego) {
      motor.eventosService.generarSemana();
    }

    // El resumen suma lo de esta semana (salarios y oficina) con lo que el
    // agente movió desde el avance anterior: traspasos, renovaciones y
    // eventos (M4). Después se vacía el acumulador de la semana en curso.
    est.ingresosUltimaSemana = ingresos + est.ingresosSemanaEnCurso;
    est.gastosUltimaSemana = gastos + est.gastosSemanaEnCurso;
    est.ingresosSemanaEnCurso = 0;
    est.gastosSemanaEnCurso = 0;

    await motor.guardarYNotificar();
  }

  /// Suma una semana a los suplentes dentro de un split (o resetea fuera).
  void _actualizarContadoresSuplentes() {
    final est = motor.estado!;
    final enSplit =
        (est.semana >= 5 && est.semana <= 18) ||
        (est.semana >= 27 && est.semana <= 40);
    for (final j in est.jugadores) {
      if (enSplit && j.equipoId != null && j.suplente) {
        j.semanasComoSuplente++;
      } else {
        j.semanasComoSuplente = 0;
      }
    }
  }

  /// Castiga con −10 de moral a quien fue suplente todo un split.
  void _castigarSuplentesDeSplit() {
    for (final j in motor.estado!.jugadores) {
      if (j.equipoId == null || !j.suplente) continue;
      if (j.semanasComoSuplente < semanasPorSplit) continue;
      j.moral = (j.moral + castigoMoralSuplenteSplit).clamp(0, 100);
      if (j.representadoPorMi) {
        motor.agregarNoticia(
          '${j.nick} pasó todo el split en el banquillo y pierde moral.',
          TipoNoticia.alerta,
        );
      }
    }
  }

  /// Reorganiza la plantilla de cada equipo: en cada rol juega el mejor y el
  /// resto son suplentes (máximo dos por equipo).
  void _reorganizarTitulares() {
    final est = motor.estado!;
    for (final equipo in est.equipos) {
      final plantilla = motor.indices.plantillaDe(equipo.id);
      final porRol = <String, List<Jugador>>{};
      for (final j in plantilla) {
        porRol.putIfAbsent(j.rol, () => <Jugador>[]).add(j);
      }
      for (final grupo in porRol.values) {
        grupo.sort((a, b) => b.habilidad.compareTo(a.habilidad));
        for (var i = 0; i < grupo.length; i++) {
          grupo[i].suplente = i > 0;
          if (i == 0) grupo[i].semanasComoSuplente = 0;
        }
      }
      for (final sobrante in mercado.recortarSuplentes(est, equipo)) {
        motor.indices.actualizar(sobrante);
        motor.agregarNoticia(
          '${sobrante.nick} quedó libre al recortar la plantilla de ${equipo.nombre}.',
          TipoNoticia.evento,
        );
      }
    }
    // Cambiaron muchos titulares/suplentes: se recalculan los índices una vez.
    motor.reconstruirIndices();
  }

  /// Ajusta el valor de mercado según la nota promedio (cada 4 semanas).
  void _ajustarValoresPorNota() {
    for (final j in motor.estado!.jugadores) {
      if (j.partidasTemporada == 0) continue;
      final promedio = j.promedioNota;
      if (promedio >= 7.5) {
        j.multiplicadorValor = (j.multiplicadorValor * 1.05).clamp(
          multiplicadorValorMinimo,
          multiplicadorValorMaximo,
        );
      } else if (promedio <= 4.5) {
        j.multiplicadorValor = (j.multiplicadorValor * 0.95).clamp(
          multiplicadorValorMinimo,
          multiplicadorValorMaximo,
        );
      }
    }
  }

  /// Aplica el progreso semanal de un jugador (mejora o empeora).
  void _progresarJugador(Jugador j) {
    aplicarProgresoSemanal(j, motor.rnd);
  }

  /// Cambio de temporada: envejecer, retiros, nuevos jóvenes y presupuestos.
  void _nuevaTemporada() {
    final est = motor.estado!;

    // Ascensos y descensos al cerrar la temporada (antes de reiniciar).
    final noticiasAscenso = procesarAscensosYDescensos(est);

    est.semana = 1;
    est.temporada++;
    motor.agregarNoticia(
      '¡Comienza la temporada ${est.temporada}!',
      TipoNoticia.evento,
    );
    for (final noticia in noticiasAscenso) {
      motor.agregarNoticia(noticia, TipoNoticia.evento);
    }

    // Envejecen todos; los de 33 o más pueden retirarse.
    final retirados = <Jugador>[];
    for (final j in est.jugadores) {
      j.edad++;
      if (j.edad >= 33 && motor.rnd.nextDouble() < 0.30) {
        retirados.add(j);
      }
    }
    for (final j in retirados) {
      final equipoId = j.equipoId;
      final rol = j.rol;
      final eraTitular = !j.suplente;
      j.representadoPorMi = false;
      est.jugadores.remove(j);
      motor.indices.eliminar(j);
      motor.agregarNoticia(
        '${j.nick} se retira a los ${j.edad} años.',
        TipoNoticia.alerta,
      );
      if (equipoId != null && eraTitular) {
        motor.reponerTitular(equipoId, rol);
      }
    }

    // Defender un título desgasta: los campeones de la temporada anterior
    // empiezan la nueva con menos moral. Ayuda a que un equipo no gane su
    // liga todas las temporadas seguidas.
    _aplicarDesgasteACampeones(est);

    // Se generan 3 jóvenes por región de cada videojuego (potencial 60–95).
    final nicksUsados = est.jugadores.map((j) => j.nick).toSet();
    for (final juego in Juego.values) {
      for (final region in motor.regionesDeJuego(juego)) {
        for (var i = 0; i < 3; i++) {
          est.jugadores.add(
            generarJovenDeRegion(
              motor.rnd,
              id: motor.nuevoId(),
              juego: juego,
              region: region,
              nicksUsados: nicksUsados,
            ),
          );
        }
      }
    }

    // Se recargan los presupuestos de los equipos.
    for (final equipo in est.equipos) {
      equipo.presupuesto = equipo.prestigio * presupuestoPorPrestigio;
    }

    // Los equipos de 2ª División pueden fichar un joven libre de su región.
    _ficharJovenesDeSegunda();

    // Se desbloquean las negociaciones y se limpian ofertas y ventanas.
    est.paresBloqueados.clear();
    est.rondasNegociacion.clear();
    est.ofertas.clear();
    est.fichajesVentana.clear();

    // Se reconstruyen las competiciones (cambian las divisiones por los
    // ascensos y descensos) y se reinician las estadísticas de temporada.
    est.competiciones = motor.competicionService.crearCompeticiones(
      est.equipos,
    );
    est.torneos = [];
    // No se borra `ceremoniaPendiente`: si el jugador no vio la ceremonia
    // antes de terminar la temporada, debe seguir disponible al cargar o
    // avanzar, en vez de perderse (M5).
    for (final j in est.jugadores) {
      // La pretemporada cura lesiones y descansos.
      j.semanasInactivo = 0;
      j.partidasTemporada = 0;
      j.victoriasTemporada = 0;
      j.notaTotalTemporada = 0;
      j.eliminacionesTemporada = 0;
      j.muertesTemporada = 0;
      j.asistenciasTemporada = 0;
      j.mvpsTemporada = 0;
      j.ultimasNotas.clear();
    }
    est.campeonesTemporada.clear();

    // Limpia lo que crece sin control con las temporadas (A3): noticias
    // viejas, ofertas vencidas y agentes libres sobrantes.
    limpiarDatosAntiguos(est);

    // Los jóvenes y reemplazos nuevos entran en los índices por id.
    motor.reconstruirIndices();
  }

  /// Resta moral a los jugadores de los equipos que ganaron un título de liga
  /// en la temporada que acaba de terminar.
  void _aplicarDesgasteACampeones(EstadoPartida est) {
    final temporadaAnterior = est.temporada - 1;
    final desde = est.temporada - 5;
    final titulosRecientes = <String, int>{};
    for (final r in est.palmares) {
      if (r.tipo != TipoCampeon.liga) continue;
      if (r.temporada < desde || r.temporada >= est.temporada) continue;
      titulosRecientes[r.ganadorId] = (titulosRecientes[r.ganadorId] ?? 0) + 1;
    }
    final campeones = <String>{
      ...est.palmares
          .where(
            (r) =>
                r.temporada == temporadaAnterior && r.tipo == TipoCampeon.liga,
          )
          .map((r) => r.ganadorId),
      // Una dinastía con 3 o más títulos recientes también arrastra desgaste.
      ...titulosRecientes.entries.where((e) => e.value >= 3).map((e) => e.key),
    };
    // Desgaste competitivo: cada título reciente por encima de 2 resta un 4 %
    // al poder del equipo, con un tope del 20 %. Se recalcula cada temporada.
    for (final equipo in est.equipos) {
      final titulos = titulosRecientes[equipo.id] ?? 0;
      final descuento = titulos <= 2 ? 0.0 : min(0.20, (titulos - 2) * 0.04);
      equipo.factorPoder = 1.0 - descuento;
    }

    if (campeones.isEmpty) return;

    for (final j in est.jugadores) {
      final equipoId = j.equipoId;
      if (equipoId == null || !campeones.contains(equipoId)) continue;
      j.moral = (j.moral - desgasteMoralCampeon).clamp(0, 100);
    }
  }

  /// Al empezar la temporada, algunos equipos de 2ª División fichan a un
  /// joven libre de su región (como suplente, sin romper la plantilla).
  void _ficharJovenesDeSegunda() {
    mercado.ficharJovenesDeSegunda(estado: motor.estado!, rnd: motor.rnd);
  }

  /// Recalcula el valor de mercado de todos los jugadores.
  void recalcularValores() {
    for (final j in motor.estado!.jugadores) {
      j.valorMercado = valorMercadoDe(j);
    }
  }
}
