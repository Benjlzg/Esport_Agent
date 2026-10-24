// Pantalla de detalle de un jugador, con las acciones disponibles.
import 'package:flutter/material.dart';

import '../logica/formulas.dart';
import '../logica/motor_juego.dart';
import '../logica/ojeadores.dart';
import '../logica/satisfaccion.dart';
import '../modelos/historial.dart';
import '../modelos/jugador.dart';
import '../tema/tema_app.dart';
import '../widgets/barra_habilidad.dart';
import '../widgets/barra_satisfaccion.dart';
import '../widgets/dialogo_confirmacion.dart';
import '../widgets/escudo_equipo.dart';
import '../widgets/estrellas_forma.dart';
import 'pantalla_negociacion.dart';
import 'pantalla_renegociacion_representacion.dart';

class PantallaDetalleJugador extends StatelessWidget {
  const PantallaDetalleJugador({
    super.key,
    required this.motor,
    required this.jugadorId,
  });

  final MotorJuego motor;
  final String jugadorId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: motor,
      builder: (context, _) {
        final jugador = motor.jugadorPorId(jugadorId);
        if (jugador == null) {
          return const Scaffold(
            body: Center(child: Text('Jugador no encontrado.')),
          );
        }
        final equipo = jugador.equipoId == null
            ? null
            : motor.equipoPorId(jugador.equipoId!);
        final agenteRival = motor.agenteRivalDe(jugador);
        // Sin partidos no hay promedio ni KDA: se muestra un guion en vez de
        // "0.00" para no confundirlo con una mala actuación.
        final sinPartidos = jugador.partidasTemporada == 0;
        final sinEstadisticasCarrera =
            jugador.eliminacionesCarrera +
                jugador.muertesCarrera +
                jugador.asistenciasCarrera ==
            0;

        return Scaffold(
          appBar: AppBar(title: const Text('Detalle del jugador')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Cabecera.
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jugador.nick,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColores.textoPrincipal,
                          ),
                        ),
                        Text(
                          jugador.nombreReal,
                          style: const TextStyle(
                            color: AppColores.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (jugador.esReal)
                    const Chip(
                      label: Text('Real'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _etiqueta(jugador.juego.nombre),
                  _etiqueta(jugador.rol),
                  _etiqueta('${jugador.edad} años'),
                  _etiqueta(jugador.pais),
                  if (equipo != null)
                    _etiqueta(jugador.suplente ? 'Suplente' : 'Titular'),
                  if (jugador.estaInactivo)
                    Chip(
                      label: Text(
                        'Fuera ${jugador.semanasInactivo} semanas',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColores.peligro,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: AppColores.peligro.withValues(
                        alpha: 0.20,
                      ),
                      side: const BorderSide(color: AppColores.peligro),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              EstrellasForma(
                estrellas: estrellasDeNotas(jugador.ultimasNotas),
                tamano: 18,
              ),
              const SizedBox(height: 16),

              // Equipo actual.
              Card(
                child: ListTile(
                  leading: equipo != null
                      ? EscudoEquipo(equipo: equipo, tamano: 40)
                      : const Icon(
                          Icons.person_outline,
                          color: AppColores.textoSecundario,
                        ),
                  title: Text(
                    equipo?.nombre ?? 'Jugador sin equipo',
                    style: const TextStyle(color: AppColores.textoPrincipal),
                  ),
                  subtitle: Text(
                    equipo != null
                        ? 'Contrato: ${jugador.semanasContrato} semanas'
                        : 'Sin equipo',
                    style: const TextStyle(
                      color: AppColores.textoSecundario,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Agente que lo representa (Parte 3A). Si no tiene agente, el
              // botón de reclutar aparece más abajo.
              if (agenteRival != null)
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.support_agent,
                      color: AppColores.acento2,
                    ),
                    title: Text(
                      'Representado por: «${agenteRival.nombre}» '
                      '(${agenteRival.perfil.etiqueta})',
                      style: const TextStyle(
                        color: AppColores.textoPrincipal,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: const Text(
                      'Puedes intentar convencerlo para que firme contigo.',
                      style: TextStyle(
                        color: AppColores.textoSecundario,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              if (agenteRival != null) const SizedBox(height: 16),

              // Satisfacción y contrato de representación (Parte 3B).
              if (jugador.representadoPorMi) ...[
                _bloqueSatisfaccion(jugador),
                const SizedBox(height: 16),
                _bloqueContrato(jugador),
                const SizedBox(height: 20),
              ],

              // Barras.
              BarraHabilidad(valor: jugador.habilidad, etiqueta: 'Habilidad'),
              const SizedBox(height: 10),
              // El potencial real nunca se imprime: siempre pasa por el texto
              // del rango visible (Parte 3C).
              Card(
                child: ListTile(
                  leading: const Icon(Icons.search, color: AppColores.acento2),
                  title: Text(
                    'Potencial ${textoPotencial(jugador)}',
                    style: const TextStyle(
                      color: AppColores.textoPrincipal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    motor.notaPrecisionPotencial(jugador),
                    style: const TextStyle(
                      color: AppColores.textoSecundario,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              BarraHabilidad(valor: jugador.moral, etiqueta: 'Moral'),
              const SizedBox(height: 20),

              // Dinero.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _fila(
                        'Valor de mercado',
                        formatearDinero(jugador.valorMercado),
                        AppColores.acento2,
                      ),
                      const SizedBox(height: 8),
                      _fila(
                        'Salario anual',
                        '${formatearDinero(jugador.salarioAnual)} al año',
                        AppColores.textoPrincipal,
                      ),
                      if (jugador.representadoPorMi) ...[
                        const SizedBox(height: 8),
                        _fila(
                          'Tiempo como representado',
                          '${jugador.semanasRepresentado} semanas',
                          jugador.semanasRepresentado >=
                                  semanasMinimasRepresentacion
                              ? AppColores.exito
                              : AppColores.dorado,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Estadísticas de la temporada y la carrera.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estadísticas',
                        style: TextStyle(
                          color: AppColores.textoPrincipal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _fila(
                        'Partidos jugados',
                        '${jugador.partidasTemporada} '
                            '(${jugador.victoriasTemporada}V · '
                            '${jugador.derrotasTemporada}D)',
                        AppColores.textoPrincipal,
                      ),
                      const SizedBox(height: 8),
                      _fila(
                        'Nota promedio',
                        sinPartidos
                            ? '—'
                            : jugador.promedioNota.toStringAsFixed(2),
                        AppColores.dorado,
                      ),
                      const SizedBox(height: 8),
                      _fila(
                        'Eliminaciones',
                        '${jugador.eliminacionesTemporada}',
                        AppColores.exito,
                      ),
                      const SizedBox(height: 8),
                      _fila(
                        'Muertes',
                        '${jugador.muertesTemporada}',
                        AppColores.peligro,
                      ),
                      const SizedBox(height: 8),
                      _fila(
                        'Asistencias',
                        '${jugador.asistenciasTemporada}',
                        AppColores.acento2,
                      ),
                      const SizedBox(height: 8),
                      _fila(
                        'KDA',
                        sinPartidos
                            ? '—'
                            : jugador.kdaTemporada.toStringAsFixed(2),
                        AppColores.textoPrincipal,
                      ),
                      const SizedBox(height: 8),
                      _fila(
                        'MVP de serie',
                        '${jugador.mvpsTemporada}',
                        AppColores.dorado,
                      ),
                      const Divider(height: 24),
                      Text(
                        'Carrera: ${jugador.eliminacionesCarrera} / '
                        '${jugador.muertesCarrera} / '
                        '${jugador.asistenciasCarrera} · '
                        'KDA ${sinEstadisticasCarrera ? '—' : jugador.kdaCarrera.toStringAsFixed(2)} · '
                        '${jugador.mvpsCarrera} MVP',
                        style: const TextStyle(
                          color: AppColores.textoSecundario,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Premios individuales.
              ..._premios(jugador.id),
              const SizedBox(height: 24),

              // Acciones.
              ..._acciones(context, jugador),
            ],
          ),
        );
      },
    );
  }

  /// Bloque de satisfacción con sus expectativas cumplidas o incumplidas.
  Widget _bloqueSatisfaccion(Jugador jugador) {
    final aviso = avisoSatisfaccion(jugador.satisfaccion);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Satisfacción',
                    style: TextStyle(
                      color: AppColores.textoPrincipal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (aviso != null)
                  Text(
                    aviso,
                    style: TextStyle(
                      color: jugador.satisfaccion < 25
                          ? AppColores.peligro
                          : AppColores.dorado,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            BarraSatisfaccion(valor: jugador.satisfaccion),
            const SizedBox(height: 12),
            const Text(
              'Expectativas',
              style: TextStyle(
                color: AppColores.textoPrincipal,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            if (jugador.expectativas.isEmpty)
              const Text(
                'Sin expectativas registradas.',
                style: TextStyle(
                  color: AppColores.textoSecundario,
                  fontSize: 12,
                ),
              )
            else
              for (final clave in jugador.expectativas)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        motor.expectativaCumplida(jugador, clave)
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: motor.expectativaCumplida(jugador, clave)
                            ? AppColores.exito
                            : AppColores.peligro,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          motor.etiquetaExpectativa(clave),
                          style: const TextStyle(
                            color: AppColores.textoPrincipal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  /// Bloque con la comisión y las semanas que quedan de representación.
  Widget _bloqueContrato(Jugador jugador) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contrato de representación',
              style: TextStyle(
                color: AppColores.textoPrincipal,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _fila(
              'Comisión',
              formatearComision(jugador.comisionSalarioContrato),
              AppColores.acento2,
            ),
            const SizedBox(height: 6),
            _fila(
              'Semanas restantes',
              '${jugador.semanasContratoRepresentacion} semanas',
              jugador.semanasContratoRepresentacion <=
                      umbralSemanasRenovacionRepresentacion
                  ? AppColores.dorado
                  : AppColores.textoPrincipal,
            ),
            if (jugador.semanasPromesaPendiente > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Promesa pendiente: ${jugador.semanasPromesaPendiente} '
                'semanas para cumplirla.',
                style: const TextStyle(color: AppColores.dorado, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Sección de premios individuales del jugador.
  List<Widget> _premios(String jugadorId) {
    final premios = motor.premiosDeJugador(jugadorId);
    if (premios.isEmpty) return const [];
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Premios',
                style: TextStyle(
                  color: AppColores.textoPrincipal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              for (final premio in premios)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: AppColores.dorado,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${nombreCategoriaPremio(premio.categoria)} '
                          '(Temp. ${premio.temporada}) · ${premio.detalle}',
                          style: const TextStyle(
                            color: AppColores.textoPrincipal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _acciones(BuildContext context, Jugador jugador) {
    if (!jugador.representadoPorMi) {
      final agenteRival = motor.agenteRivalDe(jugador);
      if (agenteRival != null) {
        // El jugador es de un rival: se puede intentar convencerlo.
        final probabilidad = motor.probabilidadConvencer(jugador) ?? 0;
        final espera = jugador.semanasEsperaConvencer;
        final enfriamiento = jugador.semanasEnfriamientoAgente;
        final bloqueado = espera > 0 || enfriamiento > 0;
        return [
          ElevatedButton.icon(
            icon: const Icon(Icons.record_voice_over),
            label: Text(
              bloqueado
                  ? 'Convencerlo'
                  : 'Convencerlo (${(probabilidad * 100).round()} % de éxito)',
            ),
            onPressed: bloqueado
                ? null
                : () => _convencer(
                    context,
                    jugador,
                    agenteRival.nombre,
                    probabilidad,
                  ),
          ),
          if (enfriamiento > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${jugador.nick} acaba de cambiar de agente: no podrá volver '
              'a hacerlo hasta dentro de $enfriamiento semanas.',
              style: const TextStyle(color: AppColores.dorado, fontSize: 12),
            ),
          ],
          if (espera > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Podrás intentarlo de nuevo en $espera semanas.',
              style: const TextStyle(
                color: AppColores.textoSecundario,
                fontSize: 12,
              ),
            ),
          ],
        ];
      }

      final costo = costoRepresentar(jugador.valorMercado);
      return [
        ElevatedButton.icon(
          icon: const Icon(Icons.handshake),
          label: Text('Reclutar por ${formatearDinero(costo)}'),
          onPressed: () => _reclutar(context, jugador, costo),
        ),
      ];
    }

    // Ventana, bloqueo y periodo mínimo se comprueban en un solo lugar de la
    // lógica, compartido con la pantalla de negociación (sección 5).
    final motivos = motor.motivosParaOfrecer(jugador);
    return [
      if (jugador.quiereHablar) ...[
        ElevatedButton.icon(
          icon: const Icon(Icons.record_voice_over),
          label: const Text('Hablar con él'),
          onPressed: () => _hablar(context, jugador),
        ),
        const SizedBox(height: 10),
      ],
      ElevatedButton.icon(
        icon: const Icon(Icons.send),
        label: const Text('Ofrecer a un equipo'),
        onPressed: motivos.isEmpty
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PantallaNegociacion(
                      motor: motor,
                      jugadorId: jugador.id,
                    ),
                  ),
                );
              }
            : null,
      ),
      for (final motivo in motivos) ...[
        const SizedBox(height: 8),
        Text(
          motivo,
          style: const TextStyle(color: AppColores.dorado, fontSize: 12),
        ),
      ],
      if (jugador.semanasContratoRepresentacion <=
          umbralSemanasRenovacionRepresentacion) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.handshake),
          label: const Text('Renegociar contrato'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PantallaRenegociacionRepresentacion(
                  motor: motor,
                  jugadorId: jugador.id,
                ),
              ),
            );
          },
        ),
      ],
      const SizedBox(height: 10),
      OutlinedButton.icon(
        icon: const Icon(Icons.person_remove),
        label: const Text('Dejar de representar'),
        onPressed: () => _dejarDeRepresentar(context, jugador),
      ),
    ];
  }

  /// Abre la conversación con un jugador insatisfecho y aplica su elección.
  Future<void> _hablar(BuildContext context, Jugador jugador) async {
    final opcion = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Hablar con ${jugador.nick}'),
        content: Text(
          '${jugador.nick} no está contento con la agencia '
          '(satisfacción ${jugador.satisfaccion}). ¿Qué le propones?\n\n'
          'Prometer mejorar: +10 ahora, pero −20 si no cumples en '
          '$semanasPromesaPendiente semanas.\n'
          'Pagar un bono: ${formatearComision(porcentajeBonoApaciguar)} de su '
          'valor y +15 de satisfacción.\n'
          'Ignorar: −$castigoIgnorarJugador de satisfacción.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('prometer'),
            child: const Text('Prometer mejorar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('bono'),
            child: const Text('Pagar un bono'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('ignorar'),
            child: const Text('Ignorar'),
          ),
        ],
      ),
    );
    if (opcion == null || !context.mounted) return;

    ResultadoAccion resultado;
    switch (opcion) {
      case 'prometer':
        resultado = await motor.prometerMejora(jugador);
      case 'bono':
        final costo = motor.costoBonoApaciguar(jugador);
        final confirmado = await mostrarConfirmacion(
          context,
          titulo: 'Pagar un bono',
          mensaje:
              'Vas a pagar ${formatearDinero(costo)} (5 % de su valor) a '
              '${jugador.nick}. Su satisfacción subirá 15 puntos.',
          textoConfirmar: 'Pagar bono',
        );
        if (!confirmado) return;
        resultado = await motor.pagarBono(jugador);
      default:
        resultado = await motor.ignorarJugador(jugador);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(resultado.mensaje)));
  }

  Future<void> _reclutar(
    BuildContext context,
    Jugador jugador,
    int costo,
  ) async {
    final confirmado = await mostrarConfirmacion(
      context,
      titulo: 'Reclutar a ${jugador.nick}',
      mensaje:
          'Vas a pagar ${formatearDinero(costo)} (5% de su valor) para representarlo.',
      textoConfirmar: 'Reclutar',
    );
    if (!confirmado || !context.mounted) return;
    final resultado = await motor.reclutar(jugador);
    if (!context.mounted) return;

    if (resultado.huboDisputa) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Disputa por ${jugador.nick}'),
          content: Text(
            resultado.ganoRival
                ? '«${resultado.rivalNombre}» también quería representar a '
                      '«${jugador.nick}» y se lo llevó.'
                : '«${resultado.rivalNombre}» también quería representar a '
                      '«${jugador.nick}», pero el jugador te eligió a ti.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(resultado.mensaje)));
  }

  /// Confirma y ejecuta un intento de convencer a un jugador de un rival.
  Future<void> _convencer(
    BuildContext context,
    Jugador jugador,
    String nombreRival,
    double probabilidad,
  ) async {
    final porcentaje = (probabilidad * 100).round();
    final confirmado = await mostrarConfirmacion(
      context,
      titulo: 'Convencer a ${jugador.nick}',
      mensaje:
          '${jugador.nick} está representado por $nombreRival.\n\n'
          'Probabilidad de éxito: $porcentaje %.\n'
          'No cuesta dinero, pero si fallas no podrás reintentarlo en '
          '13 semanas.',
      textoConfirmar: 'Intentar',
    );
    if (!confirmado || !context.mounted) return;
    final resultado = await motor.convencer(jugador);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(resultado.mensaje)));
  }

  Future<void> _dejarDeRepresentar(
    BuildContext context,
    Jugador jugador,
  ) async {
    final confirmado = await mostrarConfirmacion(
      context,
      titulo: 'Dejar de representar',
      mensaje: '¿Seguro que quieres dejar de representar a ${jugador.nick}?',
      textoConfirmar: 'Sí, dejar',
      peligroso: true,
    );
    if (!confirmado || !context.mounted) return;
    final resultado = await motor.dejarDeRepresentar(jugador);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(resultado.mensaje)));
  }

  Widget _etiqueta(String texto) {
    return Chip(
      label: Text(texto, style: const TextStyle(fontSize: 12)),
      backgroundColor: AppColores.superficie,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _fila(String titulo, String valor, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(titulo, style: const TextStyle(color: AppColores.textoSecundario)),
        Text(
          valor,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
