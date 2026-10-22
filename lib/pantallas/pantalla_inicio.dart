// Pantalla de inicio: logo, botón de nueva partida y "Continuar".
import 'package:flutter/material.dart';

import '../logica/motor_juego.dart';
import '../servicios/guardado.dart';
import '../tema/tema_app.dart';
import '../widgets/dialogo_confirmacion.dart';
import 'pantalla_crear_agente.dart';
import 'pantalla_principal.dart';

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key, required this.motor});

  final MotorJuego motor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<bool>(
        future: existePartida(),
        builder: (context, snapshot) {
          final hayGuardada = snapshot.data ?? false;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo de texto.
                  const Text(
                    'ESPORTS',
                    style: TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: AppColores.acento2,
                    ),
                  ),
                  const Text(
                    'AGENT',
                    style: TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: AppColores.acento,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tu carrera como representante de jugadores',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColores.textoSecundario),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _nuevaPartida(context, hayGuardada),
                      child: const Text('Nueva partida'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (hayGuardada)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _continuar(context),
                        child: const Text('Continuar'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _nuevaPartida(BuildContext context, bool hayGuardada) async {
    // Si ya hay una partida guardada, pido confirmación antes de borrarla.
    if (hayGuardada) {
      final confirmado = await mostrarConfirmacion(
        context,
        titulo: 'Empezar de cero',
        mensaje: 'Ya tienes una partida guardada. Si empiezas una nueva, perderás ese progreso.',
        textoConfirmar: 'Empezar nueva',
        peligroso: true,
      );
      if (!confirmado) return;
      await motor.borrar();
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PantallaCrearAgente(motor: motor)),
    );
  }

  Future<void> _continuar(BuildContext context) async {
    final carga = await motor.cargar();
    if (!context.mounted) return;
    switch (carga) {
      case ResultadoCarga.ok:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PantallaPrincipal(motor: motor)),
        );
      case ResultadoCarga.incompatible:
        await _avisarIncompatible(context);
      case ResultadoCarga.sinPartida:
      case ResultadoCarga.corrupta:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cargar la partida.')),
        );
    }
  }

  /// Avisa de que la partida guardada es de una versión anterior y ofrece
  /// empezar de nuevo.
  Future<void> _avisarIncompatible(BuildContext context) async {
    final empezar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Partida incompatible'),
        content: const Text(
          'Tu partida es de una versión anterior y no es compatible. '
          'Debes empezar una nueva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Empezar de nuevo'),
          ),
        ],
      ),
    );
    if (empezar != true || !context.mounted) return;
    await motor.borrar();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PantallaCrearAgente(motor: motor)),
    );
  }
}
