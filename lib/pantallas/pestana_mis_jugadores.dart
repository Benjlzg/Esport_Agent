// Pestaña Mi agencia: mis jugadores y el ranking de agentes (Parte 3A).
//
// La barra inferior sigue teniendo 5 pestañas. "Agentes" es una subpestaña
// dentro de Mi agencia, como permite el plan.
import 'package:flutter/material.dart';

import '../logica/motor_juego.dart';
import '../tema/tema_app.dart';
import '../widgets/tarjeta_jugador.dart';
import 'pantalla_agentes.dart';
import 'pantalla_detalle_jugador.dart';
import 'pantalla_ofertas.dart';

class PestanaMisJugadores extends StatefulWidget {
  const PestanaMisJugadores({super.key, required this.motor});

  final MotorJuego motor;

  @override
  State<PestanaMisJugadores> createState() => _PestanaMisJugadoresState();
}

class _PestanaMisJugadoresState extends State<PestanaMisJugadores> {
  /// 0 = mis jugadores, 1 = ranking de agentes.
  int _seccion = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Mis jugadores'),
                icon: Icon(Icons.groups, size: 18),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Agentes'),
                icon: Icon(Icons.people_alt, size: 18),
              ),
            ],
            selected: {_seccion},
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
            onSelectionChanged: (seleccion) {
              setState(() => _seccion = seleccion.first);
            },
          ),
        ),
        Expanded(
          child: _seccion == 0
              ? _misJugadores(context)
              : VistaAgentes(motor: widget.motor),
        ),
      ],
    );
  }

  /// Lista de mis representados y acceso a las ofertas pendientes.
  Widget _misJugadores(BuildContext context) {
    final motor = widget.motor;
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
