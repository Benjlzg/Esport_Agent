// Pantalla de ofertas recibidas (Parte 2D): traspasos por mis jugadores y
// renovaciones de contrato. Puedo aceptar, rechazar o pedir más dinero.
import 'package:flutter/material.dart';

import '../logica/formulas.dart';
import '../logica/motor_juego.dart';
import '../modelos/oferta.dart';
import '../tema/tema_app.dart';
import '../widgets/dialogo_confirmacion.dart';
import '../widgets/escudo_equipo.dart';

class PantallaOfertas extends StatelessWidget {
  const PantallaOfertas({super.key, required this.motor});

  final MotorJuego motor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: motor,
      builder: (context, _) {
        final ofertas = motor.ofertasPendientes;
        return Scaffold(
          appBar: AppBar(title: const Text('Ofertas')),
          body: ofertas.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No tienes ofertas pendientes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColores.textoSecundario),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final oferta in ofertas)
                      _tarjetaOferta(context, oferta),
                  ],
                ),
        );
      },
    );
  }

  Widget _tarjetaOferta(BuildContext context, Oferta oferta) {
    final jugador = motor.jugadorPorId(oferta.jugadorId);
    final equipo = motor.equipoPorId(oferta.equipoId);
    final esTraspaso = oferta.tipo == TipoOferta.traspaso;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (equipo != null)
                  EscudoEquipo(equipo: equipo, tamano: 40)
                else
                  const Icon(
                    Icons.shield_outlined,
                    color: AppColores.textoSecundario,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        esTraspaso
                            ? 'Oferta por ${jugador?.nick ?? 'tu jugador'}'
                            : 'Renovación de ${jugador?.nick ?? 'tu jugador'}',
                        style: const TextStyle(
                          color: AppColores.textoPrincipal,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        equipo?.nombre ?? 'Equipo desconocido',
                        style: const TextStyle(
                          color: AppColores.textoSecundario,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  esTraspaso ? 'Precio ofrecido' : 'Nuevo salario anual',
                  style: const TextStyle(color: AppColores.textoSecundario),
                ),
                Text(
                  formatearDinero(oferta.monto),
                  style: const TextStyle(
                    color: AppColores.acento2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (esTraspaso) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Salario ofrecido',
                    style: TextStyle(color: AppColores.textoSecundario),
                  ),
                  Text(
                    '${formatearDinero(oferta.salarioAnual)} al año',
                    style: const TextStyle(
                      color: AppColores.textoPrincipal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Semanas para responder',
                    style: TextStyle(color: AppColores.textoSecundario),
                  ),
                  Text(
                    '${oferta.semanasRestantes}',
                    style: TextStyle(
                      color: oferta.semanasRestantes <= 1
                          ? AppColores.peligro
                          : AppColores.textoPrincipal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _aceptar(context, oferta),
                  child: const Text('Aceptar'),
                ),
                OutlinedButton(
                  onPressed: () => _rechazar(context, oferta),
                  child: const Text('Rechazar'),
                ),
                if (esTraspaso)
                  TextButton(
                    onPressed: () => _pedirMas(context, oferta),
                    child: const Text('Pedir más'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _aceptar(BuildContext context, Oferta oferta) async {
    // Vender a un jugador es una decisión irreversible: el PLAN exige
    // confirmación (corrección I12). Las renovaciones no necesitan diálogo.
    if (oferta.tipo == TipoOferta.traspaso) {
      final jugador = motor.jugadorPorId(oferta.jugadorId);
      final equipo = motor.equipoPorId(oferta.equipoId);
      final confirmado = await mostrarConfirmacion(
        context,
        titulo: 'Vender a ${jugador?.nick ?? 'tu jugador'}',
        mensaje:
            '¿Aceptas la oferta de ${equipo?.nombre ?? 'el equipo'} por '
            '${formatearDinero(oferta.monto)}? El jugador cambiará de club.',
        textoConfirmar: 'Vender',
        peligroso: true,
      );
      if (!confirmado || !context.mounted) return;
    }
    final resultado = await motor.aceptarOferta(oferta);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(resultado.mensaje)));
  }

  Future<void> _rechazar(BuildContext context, Oferta oferta) async {
    final resultado = await motor.rechazarOferta(oferta);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(resultado.mensaje)));
  }

  Future<void> _pedirMas(BuildContext context, Oferta oferta) async {
    final resultado = await motor.pedirMasOferta(oferta);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(resultado.mensaje)));
  }
}
