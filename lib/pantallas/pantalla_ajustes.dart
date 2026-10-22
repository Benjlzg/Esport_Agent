// Pantalla de ajustes: datos del agente, frecuencia de eventos y borrar la
// partida.
import 'package:flutter/material.dart';

import '../logica/motor_juego.dart';
import '../modelos/evento.dart';
import '../tema/tema_app.dart';
import '../widgets/dialogo_confirmacion.dart';
import 'pantalla_inicio.dart';

class PantallaAjustes extends StatelessWidget {
  const PantallaAjustes({super.key, required this.motor});

  final MotorJuego motor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: motor,
      builder: (context, _) {
        // Si la partida se borró, no se pueden leer sus datos: se muestra la
        // pantalla de inicio en vez de dejar que un getter falle (C2).
        if (!motor.hayPartida) {
          return PantallaInicio(motor: motor);
        }
        final agente = motor.agente;
        return Scaffold(
          appBar: AppBar(title: const Text('Ajustes')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Agente'),
                      subtitle: Text(
                        agente.nombre,
                        style: const TextStyle(
                          color: AppColores.textoSecundario,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('País'),
                      subtitle: Text(
                        agente.pais,
                        style: const TextStyle(
                          color: AppColores.textoSecundario,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Temporada actual'),
                      subtitle: Text(
                        'Temporada ${motor.temporada} · Semana ${motor.semana}',
                        style: const TextStyle(
                          color: AppColores.textoSecundario,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ListTile(
                      title: Text('Eventos'),
                      subtitle: Text(
                        'Más frecuencia = más eventos por semana (máximo 3).',
                        style: TextStyle(color: AppColores.textoSecundario),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SegmentedButton<FrecuenciaEventos>(
                        segments: [
                          for (final frecuencia in FrecuenciaEventos.values)
                            ButtonSegment(
                              value: frecuencia,
                              label: Text(frecuencia.nombre),
                            ),
                        ],
                        selected: {motor.frecuenciaEventos},
                        onSelectionChanged: (seleccion) {
                          if (seleccion.isEmpty) return;
                          motor.cambiarFrecuenciaEventos(seleccion.first);
                        },
                      ),
                    ),
                    if (motor.semanasInversor > 0) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.account_balance,
                          color: AppColores.dorado,
                        ),
                        title: const Text('Inversor activo'),
                        subtitle: Text(
                          'Inversor: ${motor.semanasInversor} semanas',
                          style: const TextStyle(
                            color: AppColores.textoSecundario,
                          ),
                        ),
                      ),
                    ],
                    if (motor.semanasContactoGrande > 0) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.handshake,
                          color: AppColores.acento2,
                        ),
                        title: const Text('Contacto en equipo grande'),
                        subtitle: Text(
                          'Contacto en equipo grande: '
                          '${motor.semanasContactoGrande} semanas',
                          style: const TextStyle(
                            color: AppColores.textoSecundario,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColores.peligro,
                  side: const BorderSide(color: AppColores.peligro),
                ),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Borrar partida'),
                onPressed: () => _borrarPartida(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _borrarPartida(BuildContext context) async {
    // Doble confirmación: dos avisos seguidos.
    final primera = await mostrarConfirmacion(
      context,
      titulo: 'Borrar partida',
      mensaje: 'Vas a borrar tu partida para siempre. No se puede deshacer.',
      textoConfirmar: 'Continuar',
      peligroso: true,
    );
    if (!primera || !context.mounted) return;

    final segunda = await mostrarConfirmacion(
      context,
      titulo: '¿Estás completamente seguro?',
      mensaje: 'Esta acción borra todo tu progreso de forma definitiva.',
      textoConfirmar: 'Sí, borrar todo',
      peligroso: true,
    );
    if (!segunda || !context.mounted) return;

    await motor.borrar();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => PantallaInicio(motor: motor)),
      (route) => false,
    );
  }
}
