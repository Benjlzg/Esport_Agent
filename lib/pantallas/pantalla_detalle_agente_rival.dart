// Detalle de un agente rival (Parte 3A).
//
// Muestra su perfil explicado, reputación, dinero estimado y sus jugadores
// más valiosos, con acceso a la ficha de cada uno.
import 'package:flutter/material.dart';

import '../logica/agentes_rivales.dart';
import '../logica/formulas.dart';
import '../logica/motor_juego.dart';
import '../modelos/agente_rival.dart';
import '../modelos/jugador.dart';
import '../tema/tema_app.dart';
import '../widgets/barra_habilidad.dart';
import '../widgets/tarjeta_jugador.dart';
import 'pantalla_agentes.dart';
import 'pantalla_detalle_jugador.dart';

class PantallaDetalleAgenteRival extends StatelessWidget {
  const PantallaDetalleAgenteRival({
    super.key,
    required this.motor,
    required this.agenteId,
  });

  final MotorJuego motor;
  final String agenteId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: motor,
      builder: (context, _) {
        AgenteRival? rival;
        for (final agente in motor.agentesRivales) {
          if (agente.id == agenteId) {
            rival = agente;
            break;
          }
        }
        if (rival == null) {
          return const Scaffold(
            body: Center(child: Text('Agente rival no encontrado.')),
          );
        }

        final cartera = carteraDeRival(motor.estado!, rival)
          ..sort((a, b) => b.valorMercado.compareTo(a.valorMercado));
        final top = cartera.take(5).toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Detalle del agente')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              margenBotonAvanzarSemana,
            ),
            children: [
              _cabecera(rival),
              const SizedBox(height: 12),
              _tarjetaDatos(rival, cartera.length),
              const SizedBox(height: 20),
              const Text(
                'Jugadores más valiosos',
                style: TextStyle(
                  color: AppColores.textoPrincipal,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              if (top.isEmpty)
                const Text(
                  'Este agente no representa a nadie ahora mismo.',
                  style: TextStyle(color: AppColores.textoSecundario),
                )
              else
                for (final jugador in top) _jugador(context, jugador),
            ],
          ),
        );
      },
    );
  }

  /// Cabecera con nombre, país, icono y perfil explicado.
  Widget _cabecera(AgenteRival rival) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColores.acento,
          child: Icon(
            iconoDePerfil(rival.perfil),
            color: AppColores.textoPrincipal,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rival.nombre,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColores.textoPrincipal,
                ),
              ),
              Text(
                '${rival.pais} · ${rival.perfil.etiqueta}',
                style: const TextStyle(
                  color: AppColores.textoSecundario,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                rival.perfil.descripcion,
                style: const TextStyle(
                  color: AppColores.acento2,
                  fontSize: 12,
                ),
              ),
              if (rival.perfil == PerfilRival.especialista &&
                  rival.juegoEspecialidad != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Especialidad: ${rival.juegoEspecialidad!.nombre}',
                  style: const TextStyle(
                    color: AppColores.dorado,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Reputación, dinero estimado y tamaño de la cartera.
  Widget _tarjetaDatos(AgenteRival rival, int representados) {
    final dineroRedondeado = (rival.dinero / 10000).round() * 10000;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BarraHabilidad(valor: rival.reputacion, etiqueta: 'Reputación'),
            const SizedBox(height: 12),
            _fila(
              'Dinero estimado',
              '≈ ${formatearDinero(dineroRedondeado)}',
              AppColores.dorado,
            ),
            const SizedBox(height: 8),
            _fila(
              'Representados',
              '$representados',
              AppColores.textoPrincipal,
            ),
            const SizedBox(height: 8),
            _fila(
              'Valor de cartera',
              formatearDinero(valorCarteraDeRival(motor.estado!, rival)),
              AppColores.acento2,
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta de un jugador con su botón "Ver jugador".
  Widget _jugador(BuildContext context, Jugador jugador) {
    final equipo = jugador.equipoId == null
        ? null
        : motor.equipoPorId(jugador.equipoId!);
    void verJugador() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PantallaDetalleJugador(
            motor: motor,
            jugadorId: jugador.id,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Column(
          children: [
            TarjetaJugador(jugador: jugador, equipo: equipo, onTap: verJugador),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: verJugador,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Ver jugador'),
              ),
            ),
          ],
        ),
      ),
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
