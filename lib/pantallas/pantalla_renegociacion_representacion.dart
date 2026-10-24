// Pantalla para renegociar el contrato de representación (Parte 3B).
import 'package:flutter/material.dart';

import '../logica/motor_juego.dart';
import '../logica/satisfaccion.dart';
import '../tema/tema_app.dart';

/// Duraciones válidas para el nuevo contrato.
const List<int> duracionesContratoRepresentacion = [26, 52, 78, 104];

class PantallaRenegociacionRepresentacion extends StatefulWidget {
  const PantallaRenegociacionRepresentacion({
    super.key,
    required this.motor,
    required this.jugadorId,
  });

  final MotorJuego motor;
  final String jugadorId;

  @override
  State<PantallaRenegociacionRepresentacion> createState() =>
      _PantallaRenegociacionRepresentacionState();
}

class _PantallaRenegociacionRepresentacionState
    extends State<PantallaRenegociacionRepresentacion> {
  double _comision = comisionSalarioContratoInicial;
  int _duracion = contratoRepresentacionInicial;

  @override
  void initState() {
    super.initState();
    final jugador = widget.motor.jugadorPorId(widget.jugadorId);
    if (jugador != null) {
      _comision = jugador.comisionSalarioContrato.clamp(
        comisionRepresentacionMin,
        comisionRepresentacionMax,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final jugador = widget.motor.jugadorPorId(widget.jugadorId);
    if (jugador == null) {
      return const Scaffold(
        body: Center(child: Text('Jugador no encontrado.')),
      );
    }

    final maxima = widget.motor.comisionMaximaAceptablePara(
      jugador,
      _duracion,
    );
    final acepta = aceptaRenovacionRepresentacion(
      satisfaccion: jugador.satisfaccion,
      comisionOfrecida: _comision,
      duracionSemanas: _duracion,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Renegociar contrato')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jugador.nick,
                    style: const TextStyle(
                      color: AppColores.textoPrincipal,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Contrato actual: '
                    '${formatearComision(jugador.comisionSalarioContrato)} · '
                    '${jugador.semanasContratoRepresentacion} semanas',
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
          const Text(
            'Comisión sobre el salario',
            style: TextStyle(
              color: AppColores.textoPrincipal,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Del 3 % al 10 %. El jugador aceptará como máximo '
            '${formatearComision(maxima)} para $_duracion semanas.',
            style: const TextStyle(
              color: AppColores.textoSecundario,
              fontSize: 12,
            ),
          ),
          Slider(
            value: _comision,
            min: comisionRepresentacionMin,
            max: comisionRepresentacionMax,
            divisions: 7,
            label: formatearComision(_comision),
            onChanged: (valor) => setState(() => _comision = valor),
          ),
          Center(
            child: Text(
              formatearComision(_comision),
              style: const TextStyle(
                color: AppColores.acento2,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Duración',
            style: TextStyle(
              color: AppColores.textoPrincipal,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final duracion in duracionesContratoRepresentacion)
                ChoiceChip(
                  label: Text('$duracion semanas'),
                  selected: _duracion == duracion,
                  onSelected: (_) => setState(() => _duracion = duracion),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            color: acepta
                ? AppColores.exito.withValues(alpha: 0.12)
                : AppColores.peligro.withValues(alpha: 0.12),
            child: ListTile(
              leading: Icon(
                acepta ? Icons.check_circle : Icons.cancel,
                color: acepta ? AppColores.exito : AppColores.peligro,
              ),
              title: Text(
                acepta ? 'Aceptará el contrato' : 'No aceptará esta oferta',
                style: TextStyle(
                  color: acepta ? AppColores.exito : AppColores.peligro,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                acepta
                    ? '${jugador.nick} firmará '
                          '${formatearComision(_comision)} durante '
                          '$_duracion semanas.'
                    : 'Baja la comisión o elige otra duración. Para '
                          '$_duracion semanas acepta hasta '
                          '${formatearComision(maxima)}.',
                style: const TextStyle(
                  color: AppColores.textoSecundario,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.handshake),
            label: const Text('Renegociar contrato'),
            onPressed: acepta ? _confirmar : null,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmar() async {
    final jugador = widget.motor.jugadorPorId(widget.jugadorId);
    if (jugador == null) return;
    final resultado = await widget.motor.renegociarContratoRepresentacion(
      jugador,
      comision: _comision,
      duracionSemanas: _duracion,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(resultado.mensaje)));
    if (resultado.ok) Navigator.of(context).pop();
  }
}
