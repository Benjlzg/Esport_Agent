// Pantalla de negociación: ofrecer mi jugador a un equipo.
import 'package:flutter/material.dart';

import '../logica/calendario.dart';
import '../logica/formulas.dart';
import '../logica/motor_juego.dart';
import '../logica/negociacion.dart';
import '../modelos/equipo.dart';
import '../modelos/jugador.dart';
import '../tema/tema_app.dart';
import '../widgets/dialogo_confirmacion.dart';
import '../widgets/escudo_equipo.dart';

class PantallaNegociacion extends StatefulWidget {
  const PantallaNegociacion({
    super.key,
    required this.motor,
    required this.jugadorId,
  });

  final MotorJuego motor;
  final String jugadorId;

  @override
  State<PantallaNegociacion> createState() => _PantallaNegociacionState();
}

class _PantallaNegociacionState extends State<PantallaNegociacion> {
  final TextEditingController _precio = TextEditingController();
  Equipo? _equipo;
  ResultadoOferta? _resultado;

  @override
  void initState() {
    super.initState();
    // Rellena el precio con el valor de mercado sugerido y, si hay algún
    // equipo interesado, lo deja elegido para no empezar con el campo vacío.
    final jugador = widget.motor.jugadorPorId(widget.jugadorId);
    if (jugador == null) return;
    _precio.text = jugador.valorMercado.toString();
    for (final equipo in widget.motor.equiposDeJuego(jugador.juego)) {
      // El club actual no puede comprar a su propio jugador (C6).
      if (equipo.id == jugador.equipoId) continue;
      final hayInteres =
          widget.motor.interesDe(jugador, equipo) != NivelInteres.sinInteres;
      if (hayInteres && !widget.motor.bloqueado(jugador, equipo)) {
        _equipo = equipo;
        break;
      }
    }
  }

  @override
  void dispose() {
    _precio.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final jugador = widget.motor.jugadorPorId(widget.jugadorId)!;
    final equipo = _equipo!;
    // Todas las reglas (ventana, bloqueo, periodo mínimo, club actual...) se
    // comprueban en la lógica, igual que en el detalle del jugador.
    final motivos = widget.motor.motivosParaOfrecer(jugador, equipo: equipo);
    if (motivos.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(motivos.first)));
      return;
    }
    final precio = int.tryParse(_precio.text.trim());
    if (precio == null || precio <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un precio válido.')),
      );
      return;
    }
    final resultado = await widget.motor.ofrecer(
      jugador: jugador,
      equipo: equipo,
      precioPedido: precio,
    );
    if (!mounted) return;
    setState(() => _resultado = resultado);
  }

  Future<void> _aceptarContraoferta() async {
    final jugador = widget.motor.jugadorPorId(widget.jugadorId)!;
    // Aceptar la contraoferta también vende al jugador: confirmación (I12).
    final confirmado = await mostrarConfirmacion(
      context,
      titulo: 'Vender a ${jugador.nick}',
      mensaje:
          '¿Aceptas ${formatearDinero(_resultado!.contraoferta)} de '
          '${_equipo!.nombre}? ${jugador.nick} cambiará de club.',
      textoConfirmar: 'Vender',
      peligroso: true,
    );
    if (!confirmado || !mounted) return;
    final resultado = await widget.motor.aceptarContraoferta(
      jugador: jugador,
      equipo: _equipo!,
      precio: _resultado!.contraoferta,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(resultado.mensaje)));
    if (resultado.ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final motor = widget.motor;
    final jugador = motor.jugadorPorId(widget.jugadorId);
    if (jugador == null) {
      return const Scaffold(
        body: Center(child: Text('Jugador no encontrado.')),
      );
    }
    final equipos = motor
        .equiposDeJuego(jugador.juego)
        .where((e) => e.id != jugador.equipoId)
        .toList();
    // El valor inicial debe ser exactamente uno de los equipos del
    // desplegable. Si el club cambió o el equipo guardado ya no está en la
    // lista (por ejemplo, su propio club), se deja vacío para no romper.
    Equipo? equipoSeleccionado;
    if (_equipo != null) {
      for (final e in equipos) {
        if (e.id == _equipo!.id) {
          equipoSeleccionado = e;
          break;
        }
      }
    }
    final motivos = motor.motivosParaOfrecer(
      jugador,
      equipo: equipoSeleccionado,
    );
    final mercadoCerrado =
        !enVentanaFichajes(motor.semana) && jugador.equipoId != null;
    final recienFichado = jugador.bloqueadoTraspaso(motor.temporada);
    final semanasFaltantes =
        semanasMinimasRepresentacion - jugador.semanasRepresentado;

    return Scaffold(
      appBar: AppBar(title: Text('Ofrecer a ${jugador.nick}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (mercadoCerrado) ...[
            Card(
              color: AppColores.superficie,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock, color: AppColores.peligro),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'El mercado está cerrado. '
                        '${proximaVentanaTexto(motor.semana)} '
                        'Los agentes libres sí se pueden fichar.',
                        style: const TextStyle(
                          color: AppColores.peligro,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (recienFichado) ...[
            Card(
              color: AppColores.superficie,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock, color: AppColores.dorado),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Recién fichado: podrá cambiar de equipo la próxima '
                        'temporada.',
                        style: const TextStyle(
                          color: AppColores.dorado,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (semanasFaltantes > 0) ...[
            Card(
              color: AppColores.superficie,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.hourglass_bottom,
                      color: AppColores.dorado,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Llevas ${jugador.semanasRepresentado} de '
                        '$semanasMinimasRepresentacion semanas como su agente. '
                        'Podrás ofrecerlo dentro de $semanasFaltantes '
                        'semana${semanasFaltantes == 1 ? '' : 's'}.',
                        style: const TextStyle(
                          color: AppColores.dorado,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Valor de mercado sugerido',
                    style: TextStyle(color: AppColores.textoSecundario),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatearDinero(jugador.valorMercado),
                    style: const TextStyle(
                      color: AppColores.acento2,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Elegir equipo (solo del mismo videojuego).
          DropdownButtonFormField<Equipo>(
            initialValue: equipoSeleccionado,
            // Ocupa todo el ancho y recorta con puntos suspensivos los nombres
            // largos, para que no se salgan en pantallas estrechas.
            isExpanded: true,
            dropdownColor: AppColores.superficie,
            decoration: const InputDecoration(labelText: 'Equipo interesado'),
            items: equipos
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      '${e.nombre} (Prestigio ${e.prestigio})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (equipo) {
              setState(() {
                _equipo = equipo;
                _resultado = null;
                if (equipo != null) {
                  _precio.text = jugador.valorMercado.toString();
                }
              });
            },
          ),
          const SizedBox(height: 12),

          // Indicador de interés y rondas.
          if (_equipo != null) _panelInteres(jugador, _equipo!),
          const SizedBox(height: 12),

          // Precio pedido.
          TextField(
            controller: _precio,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Precio pedido (\$)',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Enviar oferta'),
            onPressed: (_equipo == null || motivos.isNotEmpty) ? null : _enviar,
          ),

          const SizedBox(height: 20),

          // Respuesta del equipo.
          if (_resultado != null) _panelRespuesta(_resultado!),
        ],
      ),
    );
  }

  Widget _panelInteres(Jugador jugador, Equipo equipo) {
    final interes = widget.motor.interesDe(jugador, equipo);
    final restantes = widget.motor.rondasRestantes(jugador, equipo);
    final bloqueado = widget.motor.bloqueado(jugador, equipo);

    late String texto;
    late Color color;
    switch (interes) {
      case NivelInteres.muyInteresado:
        texto = 'Muy interesado';
        color = AppColores.exito;
      case NivelInteres.interesado:
        texto = 'Interesado';
        color = AppColores.dorado;
      case NivelInteres.sinInteres:
        texto = 'Sin interés';
        color = AppColores.peligro;
    }

    return Row(
      children: [
        EscudoEquipo(equipo: equipo, tamano: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                texto,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
              Text(
                bloqueado
                    ? 'No negocia más esta temporada'
                    : 'Rondas restantes: $restantes',
                style: const TextStyle(
                  color: AppColores.textoSecundario,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panelRespuesta(ResultadoOferta resultado) {
    Color color;
    switch (resultado.respuesta) {
      case RespuestaEquipo.acepta:
        color = AppColores.exito;
      case RespuestaEquipo.contraoferta:
        color = AppColores.dorado;
      case RespuestaEquipo.rechaza:
      case RespuestaEquipo.sinInteres:
      case RespuestaEquipo.sinPresupuesto:
        color = AppColores.peligro;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              resultado.mensaje,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            if (resultado.respuesta == RespuestaEquipo.contraoferta) ...[
              const SizedBox(height: 10),
              Text(
                'Oferta del equipo: ${formatearDinero(resultado.contraoferta)}',
                style: const TextStyle(color: AppColores.textoPrincipal),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _aceptarContraoferta,
                child: const Text('Aceptar'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => setState(() => _resultado = null),
                child: const Text('Pedir más'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
