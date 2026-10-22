// Pestaña Mi agencia: los jugadores que represento y acceso a las ofertas.
import 'package:flutter/material.dart';

import '../logica/motor_juego.dart';
import '../tema/tema_app.dart';
import '../widgets/tarjeta_jugador.dart';
import 'pantalla_detalle_jugador.dart';
import 'pantalla_ofertas.dart';

class PestanaMisJugadores extends StatelessWidget {
  const PestanaMisJugadores({super.key, required this.motor});

  final MotorJuego motor;

  @override
  Widget build(BuildContext context) {
    final jugadores = motor.misJugadores;
    final ofertas = motor.ofertasPendientes.length;

    final acceso = ofertas == 0
        ? null
        : Card(
            child: ListTile(
              leading: Badge.count(
                count: ofertas,
                backgroundColor: AppColores.peligro,
                child: const Icon(Icons.mail),
              ),
              title: Text(
                ofertas == 1
                    ? 'Tienes 1 oferta pendiente'
                    : 'Tienes $ofertas ofertas pendientes',
                style: const TextStyle(
                  color: AppColores.textoPrincipal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Toca para aceptar, rechazar o pedir más.',
                style: TextStyle(
                  color: AppColores.textoSecundario,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PantallaOfertas(motor: motor),
                  ),
                );
              },
            ),
          );

    if (jugadores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (acceso != null) ...[acceso, const SizedBox(height: 16)],
              const Text(
                'Aún no representas a nadie. Ve al Mercado para reclutar tu primer jugador.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColores.textoSecundario),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, margenBotonAvanzarSemana),
      children: [
        if (acceso != null) ...[acceso, const SizedBox(height: 4)],
        for (final jugador in jugadores)
          TarjetaJugador(
            jugador: jugador,
            equipo: jugador.equipoId == null
                ? null
                : motor.equipoPorId(jugador.equipoId!),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PantallaDetalleJugador(
                    motor: motor,
                    jugadorId: jugador.id,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
