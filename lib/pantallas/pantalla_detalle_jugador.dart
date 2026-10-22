// Pantalla de detalle de un jugador, con las acciones disponibles.
import 'package:flutter/material.dart';

import '../logica/calendario.dart';
import '../logica/formulas.dart';
import '../logica/motor_juego.dart';
import '../modelos/historial.dart';
import '../modelos/jugador.dart';
import '../tema/tema_app.dart';
import '../widgets/barra_habilidad.dart';
import '../widgets/dialogo_confirmacion.dart';
import '../widgets/escudo_equipo.dart';
import '../widgets/estrellas_forma.dart';
import 'pantalla_negociacion.dart';

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
                    equipo?.nombre ?? 'Agente libre',
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

              // Barras.
              BarraHabilidad(valor: jugador.habilidad, etiqueta: 'Habilidad'),
              const SizedBox(height: 10),
              BarraHabilidad(valor: jugador.potencial, etiqueta: 'Potencial'),
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
    final mercadoCerrado =
        !enVentanaFichajes(motor.semana) && jugador.equipoId != null;
    final recienFichado = jugador.bloqueadoTraspaso(motor.temporada);
    final semanasFaltantes =
        semanasMinimasRepresentacion - jugador.semanasRepresentado;
    if (!jugador.representadoPorMi) {
      final costo = costoRepresentar(jugador.valorMercado);
      return [
        ElevatedButton.icon(
          icon: const Icon(Icons.handshake),
          label: Text('Reclutar por ${formatearDinero(costo)}'),
          onPressed: () => _reclutar(context, jugador, costo),
        ),
      ];
    }

    return [
      ElevatedButton.icon(
        icon: const Icon(Icons.send),
        label: const Text('Ofrecer a un equipo'),
        onPressed: (mercadoCerrado || recienFichado || semanasFaltantes > 0)
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PantallaNegociacion(
                      motor: motor,
                      jugadorId: jugador.id,
                    ),
                  ),
                );
              },
      ),
      if (semanasFaltantes > 0) ...[
        const SizedBox(height: 8),
        Text(
          'Debes representarlo al menos $semanasMinimasRepresentacion semanas '
          'antes de ofrecerlo. Te faltan $semanasFaltantes '
          'semana${semanasFaltantes == 1 ? '' : 's'}.',
          style: const TextStyle(color: AppColores.dorado, fontSize: 12),
        ),
      ],
      if (recienFichado) ...[
        const SizedBox(height: 8),
        const Text(
          'Recién fichado: podrá cambiar de equipo la próxima temporada.',
          style: TextStyle(color: AppColores.dorado, fontSize: 12),
        ),
      ],
      if (mercadoCerrado) ...[
        const SizedBox(height: 8),
        Text(
          'El mercado está cerrado. ${proximaVentanaTexto(motor.semana)}',
          style: const TextStyle(color: AppColores.peligro, fontSize: 12),
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
