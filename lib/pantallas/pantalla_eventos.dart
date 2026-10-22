// Ventana emergente de los eventos aleatorios (Parte 2E).
//
// Recorre los eventos pendientes uno tras otro. Si una opción cuesta dinero,
// muestra el costo ya limitado y pide confirmación antes de cobrar.
import 'package:flutter/material.dart';

import '../logica/eventos.dart';
import '../logica/formulas.dart';
import '../logica/motor_juego.dart';
import '../modelos/evento.dart';
import '../tema/tema_app.dart';
import '../widgets/dialogo_confirmacion.dart';

/// Muestra todos los eventos pendientes del motor, uno detrás de otro.
///
/// Cada evento queda pendiente hasta que se resuelve. Si el usuario cancela
/// la confirmación de un gasto, no se cobra nada y el evento se conserva.
Future<void> mostrarEventosPendientes(
  BuildContext context,
  MotorJuego motor,
) async {
  // Se recorre una copia: resolver un evento modifica la lista del motor.
  final pendientes = List<EventoPendiente>.of(motor.eventosPendientes);
  for (final evento in pendientes) {
    if (!context.mounted) return;
    // Puede haberse resuelto entre la copia y este momento.
    final siguePendiente = motor.eventosPendientes.any(
      (e) => e.id == evento.id,
    );
    if (!siguePendiente) continue;

    final opcion = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _DialogoEvento(motor: motor, evento: evento),
    );
    if (opcion == null || opcion < 0) continue;
    await motor.resolverEvento(evento, opcion);
  }
}

/// Diálogo de un solo evento con sus opciones y costos limitados.
class _DialogoEvento extends StatelessWidget {
  const _DialogoEvento({required this.motor, required this.evento});

  final MotorJuego motor;
  final EventoPendiente evento;

  @override
  Widget build(BuildContext context) {
    final dinero = motor.agente.dinero;
    final costoA = limitarCostoEvento(evento.costoBaseDe(0), dinero);
    final costoB = limitarCostoEvento(evento.costoBaseDe(1), dinero);
    final ingresoA = evento.ingresoDe(0);
    final ingresoB = evento.ingresoDe(1);
    // El aviso del 30 % solo aplica a opciones que CUESTAN dinero.
    final tieneCosto = costoA > 0 || costoB > 0;

    return AlertDialog(
      backgroundColor: AppColores.superficie,
      title: Text(evento.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            evento.descripcion,
            style: const TextStyle(color: AppColores.textoSecundario),
          ),
          if (tieneCosto) ...[
            const SizedBox(height: 12),
            const Text(
              'Los costos ya están limitados al 30 % de tu dinero actual.',
              style: TextStyle(color: AppColores.dorado, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: evento.esDecision
          ? [
              TextButton(
                onPressed: () => _elegir(context, 1, costoB),
                child: Text(
                  _textoOpcion(evento.opcionB ?? 'Rechazar', costoB, ingresoB),
                  style: const TextStyle(color: AppColores.textoSecundario),
                ),
              ),
              ElevatedButton(
                onPressed: () => _elegir(context, 0, costoA),
                child: Text(
                  _textoOpcion(evento.opcionA ?? 'Aceptar', costoA, ingresoA),
                ),
              ),
            ]
          : [
              ElevatedButton(
                onPressed: () => _elegir(context, 0, costoA),
                child: Text(_textoOpcion('Entendido', costoA, ingresoA)),
              ),
            ],
    );
  }

  /// Texto del botón con el costo final (limitado) y/o el ingreso.
  /// Los ingresos se muestran con "+" y los costos con "−" (corrección A1).
  String _textoOpcion(String texto, int costo, int ingreso) {
    final partes = <String>[
      if (ingreso > 0) '+${formatearDinero(ingreso)}',
      if (costo > 0) '−${formatearDinero(costo)}',
    ];
    if (partes.isEmpty) return texto;
    return '$texto (${partes.join(' · ')})';
  }

  /// Pide confirmación cuando la opción cuesta dinero y resuelve el evento.
  Future<void> _elegir(
    BuildContext dialogContext,
    int opcion,
    int costo,
  ) async {
    if (costo > 0) {
      final confirmado = await mostrarConfirmacion(
        dialogContext,
        titulo: 'Confirmar gasto',
        mensaje: 'Vas a pagar ${formatearDinero(costo)}. ¿Quieres continuar?',
        textoConfirmar: 'Pagar',
      );
      // Si cancela, el diálogo del evento sigue abierto y no se cobra nada.
      if (!confirmado || !dialogContext.mounted) return;
    }
    Navigator.of(dialogContext).pop(opcion);
  }
}
