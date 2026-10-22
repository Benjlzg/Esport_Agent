// Ceremonia de premios: muestra los ganadores de la temporada uno tras otro
// (PageView) con un botón para avanzar. Se abre automáticamente al llegar a
// la semana 47 y el motor la marca como vista al cerrarla.
import 'package:flutter/material.dart';

import '../logica/motor_juego.dart';
import '../modelos/historial.dart';
import '../tema/tema_app.dart';

class PantallaCeremoniaPremios extends StatefulWidget {
  const PantallaCeremoniaPremios({super.key, required this.motor});

  final MotorJuego motor;

  @override
  State<PantallaCeremoniaPremios> createState() =>
      _PantallaCeremoniaPremiosState();
}

class _PantallaCeremoniaPremiosState extends State<PantallaCeremoniaPremios> {
  late final List<PremioIndividual> _premios;
  final PageController _controlador = PageController();
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    _premios = widget.motor.estado!.premios
        .where((p) => p.temporada == widget.motor.temporada)
        .toList();
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ceremonia · Temp. ${widget.motor.temporada}'),
        actions: [TextButton(onPressed: _cerrar, child: const Text('Saltar'))],
      ),
      body: _premios.isEmpty
          ? const Center(
              child: Text(
                'No hay premios que entregar.',
                style: TextStyle(color: AppColores.textoSecundario),
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Premio ${_indice + 1} de ${_premios.length}',
                    style: const TextStyle(
                      color: AppColores.textoSecundario,
                      fontSize: 12,
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controlador,
                      itemCount: _premios.length,
                      onPageChanged: (i) => setState(() => _indice = i),
                      itemBuilder: (context, i) => _pagina(_premios[i]),
                    ),
                  ),
                  _puntos(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(
                          _indice == _premios.length - 1
                              ? Icons.check
                              : Icons.arrow_forward,
                        ),
                        label: Text(
                          _indice == _premios.length - 1
                              ? 'Finalizar'
                              : 'Siguiente',
                        ),
                        onPressed: _avanzar,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Una página de la ceremonia: categoría, ganador y detalle.
  Widget _pagina(PremioIndividual premio) {
    final jugador = premio.jugadorId == null
        ? null
        : widget.motor.jugadorPorId(premio.jugadorId!);
    final esAgente = premio.categoria == CategoriaPremio.agenteDelAnio;
    final ganador = esAgente
        ? (premio.nombreAgente ?? 'Tu agencia')
        : (jugador?.nick ?? '—');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: AppColores.dorado,
                  size: 56,
                ),
                const SizedBox(height: 12),
                Text(
                  nombreCategoriaPremio(premio.categoria),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColores.dorado,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  premio.juego == null ? 'Premio global' : premio.juego!.nombre,
                  style: const TextStyle(
                    color: AppColores.textoSecundario,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  ganador,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColores.textoPrincipal,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                if (jugador != null && jugador.equipoId != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.motor.equipoPorId(jugador.equipoId!)?.nombre ?? '',
                    style: const TextStyle(
                      color: AppColores.acento2,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  premio.detalle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColores.textoSecundario,
                    fontSize: 13,
                  ),
                ),
                if (widget.motor.misJugadores.any(
                      (j) => j.id == premio.jugadorId,
                    ) ||
                    esAgente) ...[
                  const SizedBox(height: 16),
                  const Chip(
                    avatar: Icon(
                      Icons.star,
                      size: 16,
                      color: AppColores.dorado,
                    ),
                    label: Text('¡Tuyo!', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _puntos() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _premios.length; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == _indice
                  ? AppColores.acento2
                  : AppColores.textoSecundario.withValues(alpha: 0.4),
            ),
          ),
      ],
    );
  }

  void _avanzar() {
    if (_indice >= _premios.length - 1) {
      _cerrar();
      return;
    }
    _controlador.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _cerrar() => Navigator.of(context).pop();
}
