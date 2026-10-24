// Pestaña Resumen: dinero, reputación, mejores jugadores y noticias.
import 'package:flutter/material.dart';

import '../logica/formulas.dart';
import '../logica/motor_juego.dart';
import '../tema/tema_app.dart';
import '../widgets/barra_habilidad.dart';
import '../widgets/barra_satisfaccion.dart';
import '../widgets/escudo_equipo.dart';
import '../widgets/tarjeta_jugador.dart';
import 'pantalla_detalle_jugador.dart';
import 'pantalla_academia.dart';
import 'pantalla_previa_partido.dart';
import 'pestana_noticias.dart';

class PestanaResumen extends StatelessWidget {
  const PestanaResumen({super.key, required this.motor});

  final MotorJuego motor;

  @override
  Widget build(BuildContext context) {
    final agente = motor.agente;
    final mejores = motor.misMejoresJugadores;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, margenBotonAvanzarSemana),
      children: [
        // Tarjeta de dinero y balance de la semana pasada.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tu dinero',
                  style: TextStyle(color: AppColores.textoSecundario),
                ),
                const SizedBox(height: 6),
                Text(
                  formatearDinero(agente.dinero),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: agente.dinero < 0
                        ? AppColores.peligro
                        : AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _EtiquetaBalance(
                      texto:
                          'Ganado: ${formatearDinero(motor.ingresosSemanaActual)}',
                      color: AppColores.exito,
                    ),
                    const SizedBox(width: 16),
                    _EtiquetaBalance(
                      texto:
                          'Gastado: ${formatearDinero(motor.gastosSemanaActual)}',
                      color: AppColores.peligro,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Tarjeta de reputación.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reputación',
                  style: TextStyle(color: AppColores.textoSecundario),
                ),
                const SizedBox(height: 8),
                BarraHabilidad(valor: agente.reputacion, etiqueta: 'Nivel'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Aviso de jóvenes de la academia listos para colocar (Parte 3E).
        ..._avisoAcademia(context),

        // Salud de la agencia (Parte 3B).
        ..._saludAgencia(),

        // Campeones internacionales de la temporada (si ya hay alguno).
        ..._campeonesInternacionales(),

        const Text(
          'Próximos partidos de mis jugadores',
          style: TextStyle(
            color: AppColores.textoPrincipal,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ..._proximosPartidos(context),
        const SizedBox(height: 20),

        const Text(
          'Mis jugadores más valiosos',
          style: TextStyle(
            color: AppColores.textoPrincipal,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        if (mejores.isEmpty)
          const Text(
            'Aún no representas a nadie. Ve al Mercado para reclutar.',
            style: TextStyle(color: AppColores.textoSecundario),
          )
        else
          ...mejores.map(
            (jugador) => TarjetaJugador(
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
          ),
        const SizedBox(height: 20),

        Row(
          children: [
            const Expanded(
              child: Text(
                'Últimas noticias',
                style: TextStyle(
                  color: AppColores.textoPrincipal,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Noticias')),
                      body: PestanaNoticias(motor: motor),
                    ),
                  ),
                );
              },
              child: const Text('Ver todas'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...motor.ultimasNoticias.map((n) => FilaNoticia(noticia: n)),
      ],
    );
  }

  /// Aviso destacado si hay jóvenes que ya cumplen los requisitos de
  /// colocación. La ventana se indica aparte para no confundir "listo" con
  /// "el mercado está abierto".
  List<Widget> _avisoAcademia(BuildContext context) {
    final listos = motor.jovenesListosParaColocar;
    if (listos.isEmpty) return const [];
    final abierta = motor.ventanaAcademiaAbierta;
    return [
      Card(
        child: ListTile(
          leading: const Icon(Icons.school, color: AppColores.dorado),
          title: const Text(
            'Tienes jóvenes listos para colocar',
            style: TextStyle(
              color: AppColores.textoPrincipal,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            abierta
                ? '${listos.length} joven${listos.length == 1 ? '' : 'es'} '
                      'puede${listos.length == 1 ? '' : 'n'} fichar por un '
                      'equipo de 2ª División. Abre la Academia para colocarlo.'
                : '${listos.length} joven${listos.length == 1 ? '' : 'es'} '
                      'cumple${listos.length == 1 ? '' : 'n'} los requisitos. '
                      'El mercado está cerrado; podrás colocarlo en la '
                      'próxima ventana.',
            style: const TextStyle(
              color: AppColores.textoSecundario,
              fontSize: 12,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PantallaAcademia(motor: motor)),
            );
          },
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  /// Tarjeta con satisfacción media y los representados más descontentos.
  List<Widget> _saludAgencia() {
    final jugadores = motor.misJugadores;
    if (jugadores.isEmpty) return const [];
    final media = motor.satisfaccionMedia.round();
    final descontentos = motor.representadosMasDescontentos();
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Salud de la agencia',
                style: TextStyle(
                  color: AppColores.textoPrincipal,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              BarraSatisfaccion(valor: media, etiqueta: 'Satisfacción media'),
              const SizedBox(height: 12),
              const Text(
                'Los más descontentos',
                style: TextStyle(
                  color: AppColores.textoSecundario,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              for (final jugador in descontentos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person,
                        color: AppColores.textoSecundario,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          jugador.nick,
                          style: const TextStyle(
                            color: AppColores.textoPrincipal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '${jugador.satisfaccion}',
                        style: TextStyle(
                          color: colorSatisfaccion(jugador.satisfaccion),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  /// Tarjeta destacada con los campeones internacionales de la temporada.
  List<Widget> _campeonesInternacionales() {
    final torneos = motor.torneosDeTemporada
        .where((t) => t.campeonId != null)
        .toList();
    if (torneos.isEmpty) return const [];

    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Campeones internacionales',
                style: TextStyle(
                  color: AppColores.textoPrincipal,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              for (final torneo in torneos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: AppColores.dorado,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${torneo.nombre} de ${torneo.juego.corto}',
                          style: const TextStyle(
                            color: AppColores.textoSecundario,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        motor.equipoPorId(torneo.campeonId!)?.nombre ?? '',
                        style: const TextStyle(
                          color: AppColores.dorado,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  /// Tarjetas con los próximos partidos de mis representados.
  List<Widget> _proximosPartidos(BuildContext context) {
    final proximos = motor.proximosPartidosDeMisJugadores;
    if (proximos.isEmpty) {
      return const [
        Text(
          'No hay partidos programados para tus representados.',
          style: TextStyle(color: AppColores.textoSecundario),
        ),
      ];
    }
    return proximos.map((p) {
      final miEquipo = motor.equipoPorId(p.miEquipoId);
      final rival = motor.equipoPorId(p.rivalId);
      if (miEquipo == null || rival == null) return const SizedBox.shrink();
      return Card(
        child: ListTile(
          leading: EscudoEquipo(equipo: miEquipo, tamano: 40),
          title: Text(
            '${miEquipo.nombre} vs ${rival.nombre}',
            style: const TextStyle(
              color: AppColores.textoPrincipal,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            '${p.competicion.liga} · Fecha ${p.fecha} · '
            '${p.esLocal ? 'Local' : 'Visitante'}',
            style: const TextStyle(
              color: AppColores.textoSecundario,
              fontSize: 12,
            ),
          ),
          trailing: const Icon(Icons.insights, color: AppColores.acento2),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PantallaPreviaPartido(
                  motor: motor,
                  competicion: p.competicion,
                  localId: p.localId,
                  visitanteId: p.visitanteId,
                ),
              ),
            );
          },
        ),
      );
    }).toList();
  }
}

/// Pequeña etiqueta para mostrar dinero ganado o gastado.
class _EtiquetaBalance extends StatelessWidget {
  const _EtiquetaBalance({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(texto, style: TextStyle(color: color, fontSize: 13));
  }
}
