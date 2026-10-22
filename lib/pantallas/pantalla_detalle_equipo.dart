// Pantalla de detalle de un equipo, con su plantilla de 5 jugadores.
import 'package:flutter/material.dart';

import '../logica/formulas.dart';
import '../logica/motor_juego.dart';
import '../modelos/equipo.dart';
import '../modelos/historial.dart';
import '../modelos/jugador.dart';
import '../tema/tema_app.dart';
import '../widgets/barra_habilidad.dart';
import '../widgets/escudo_equipo.dart';
import 'pantalla_detalle_jugador.dart';

class PantallaDetalleEquipo extends StatelessWidget {
  const PantallaDetalleEquipo({
    super.key,
    required this.motor,
    required this.equipoId,
  });

  final MotorJuego motor;
  final String equipoId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: motor,
      builder: (context, _) {
        final equipo = motor.equipoPorId(equipoId);
        if (equipo == null) {
          return const Scaffold(
            body: Center(child: Text('Equipo no encontrado.')),
          );
        }
        final competicion = motor.competicion(
          equipo.juego,
          equipo.region,
          equipo.division,
        );
        final forma = competicion?.formaEquipo(equipo.id) ?? const <String>[];
        final rivales = equipo.rivales
            .map((id) => motor.equipoPorId(id))
            .whereType<Equipo>()
            .toList();

        return Scaffold(
          appBar: AppBar(title: Text(equipo.nombre)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Cabecera con el escudo grande.
              Center(
                child: Column(
                  children: [
                    EscudoEquipo(equipo: equipo, tamano: 96),
                    const SizedBox(height: 12),
                    Text(
                      equipo.nombre,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${equipo.juego.nombre} · ${equipo.region}',
                      style: const TextStyle(color: AppColores.textoSecundario),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${equipo.division}ª División · ${equipo.liga}',
                      style: const TextStyle(
                        color: AppColores.textoSecundario,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      BarraHabilidad(
                        valor: equipo.prestigio,
                        etiqueta: 'Prestigio',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Presupuesto',
                            style: TextStyle(color: AppColores.textoSecundario),
                          ),
                          Text(
                            formatearDinero(equipo.presupuesto),
                            style: const TextStyle(
                              color: AppColores.acento2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Forma reciente y rivales clásicos.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Forma reciente',
                        style: TextStyle(
                          color: AppColores.textoPrincipal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (forma.isEmpty)
                        const Text(
                          'Sin partidos jugados todavía.',
                          style: TextStyle(
                            color: AppColores.textoSecundario,
                            fontSize: 12,
                          ),
                        )
                      else
                        Row(children: forma.map(_chipForma).toList()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Campeones de la liga de este equipo.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Liga · ${equipo.liga}',
                        style: const TextStyle(
                          color: AppColores.textoPrincipal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _filaCampeon('Split 1', competicion?.campeonSplit(1)),
                      const SizedBox(height: 4),
                      _filaCampeon('Split 2', competicion?.campeonSplit(2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Títulos del equipo (derivados del Palmarés).
              ..._titulos(equipo.id),
              if (rivales.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Clásicos / Rivales',
                          style: TextStyle(
                            color: AppColores.textoPrincipal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...rivales.map(
                          (rival) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: EscudoEquipo(equipo: rival, tamano: 36),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    rival.nombre,
                                    style: const TextStyle(
                                      color: AppColores.textoPrincipal,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.local_fire_department,
                                  color: AppColores.peligro,
                                  size: 18,
                                ),
                              ],
                            ),
                            subtitle: const Text(
                              'Clásico',
                              style: TextStyle(
                                color: AppColores.peligro,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PantallaDetalleEquipo(
                                    motor: motor,
                                    equipoId: rival.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              const Text(
                'Titulares',
                style: TextStyle(
                  color: AppColores.textoPrincipal,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...motor
                  .titularesDe(equipo.id)
                  .map((j) => _filaJugador(context, j)),
              if (motor.suplentesDe(equipo.id).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Suplentes',
                  style: TextStyle(
                    color: AppColores.textoPrincipal,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...motor
                    .suplentesDe(equipo.id)
                    .map((j) => _filaJugador(context, j)),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Tarjeta de un jugador de la plantilla, con acceso a su ficha.
  Widget _filaJugador(BuildContext context, Jugador jugador) {
    return Card(
      child: ListTile(
        leading: jugador.estaInactivo
            ? const Icon(Icons.medical_services, color: AppColores.peligro)
            : null,
        title: Text(
          '${jugador.rol} · ${jugador.nick}',
          style: const TextStyle(color: AppColores.textoPrincipal),
        ),
        subtitle: Text(
          jugador.estaInactivo
              ? 'Habilidad ${jugador.habilidad} · ${jugador.edad} años · '
                    'Fuera ${jugador.semanasInactivo} semanas'
              : 'Habilidad ${jugador.habilidad} · ${jugador.edad} años',
          style: TextStyle(
            color: jugador.estaInactivo
                ? AppColores.peligro
                : AppColores.textoSecundario,
            fontSize: 12,
          ),
        ),
        trailing: Text(
          formatearDinero(jugador.valorMercado),
          style: const TextStyle(color: AppColores.acento2, fontSize: 12),
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  PantallaDetalleJugador(motor: motor, jugadorId: jugador.id),
            ),
          );
        },
      ),
    );
  }

  /// Sección de títulos del equipo (ligas y torneos del Palmarés).
  List<Widget> _titulos(String id) {
    final titulos = motor.titulosDeEquipo(id);
    if (titulos.isEmpty) return const [];
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Títulos',
                style: TextStyle(
                  color: AppColores.textoPrincipal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              for (final titulo in titulos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        titulo.tipo == TipoCampeon.torneo
                            ? Icons.emoji_events
                            : Icons.military_tech,
                        color: AppColores.dorado,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          titulo.descripcion,
                          style: const TextStyle(
                            color: AppColores.textoPrincipal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        'Temp. ${titulo.temporada}',
                        style: const TextStyle(
                          color: AppColores.dorado,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  /// Chip verde (victoria) o rojo (derrota) para la forma reciente.
  Widget _chipForma(String resultado) {
    final gano = resultado == 'V';
    return Container(
      margin: const EdgeInsets.only(right: 6),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: (gano ? AppColores.exito : AppColores.peligro).withValues(
          alpha: 0.25,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        resultado,
        style: TextStyle(
          color: gano ? AppColores.exito : AppColores.peligro,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  /// Fila con el campeón de un split (o "Por decidir"). Marca con un trofeo
  /// si el campeón es este mismo equipo.
  Widget _filaCampeon(String split, String? campeonId) {
    if (campeonId == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            split,
            style: const TextStyle(color: AppColores.textoSecundario),
          ),
          const Text(
            'Por decidir',
            style: TextStyle(color: AppColores.textoSecundario, fontSize: 12),
          ),
        ],
      );
    }
    final campeon = motor.equipoPorId(campeonId);
    final esEste = campeonId == equipoId;
    return Row(
      children: [
        Text(split, style: const TextStyle(color: AppColores.textoSecundario)),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  campeon?.nombre ?? campeonId,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: esEste
                        ? AppColores.dorado
                        : AppColores.textoPrincipal,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              if (esEste) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.emoji_events,
                  color: AppColores.dorado,
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
