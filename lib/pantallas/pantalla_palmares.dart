// Pantalla Palmarés: todos los títulos ganados por temporada (ligas y
// torneos) y los premios individuales de cada ceremonia.
import 'package:flutter/material.dart';

import '../logica/motor_juego.dart';
import '../modelos/historial.dart';
import '../tema/tema_app.dart';
import '../widgets/escudo_equipo.dart';

class PantallaPalmares extends StatelessWidget {
  const PantallaPalmares({super.key, required this.motor});

  final MotorJuego motor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Palmarés')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Campeones',
            style: TextStyle(
              color: AppColores.textoPrincipal,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ..._seccionesTitulos(),
          const SizedBox(height: 20),
          const Text(
            'Premios individuales',
            style: TextStyle(
              color: AppColores.textoPrincipal,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ..._seccionesPremios(),
        ],
      ),
    );
  }

  /// Títulos agrupados por temporada (de la más reciente a la más antigua).
  List<Widget> _seccionesTitulos() {
    final palmares = motor.estado!.palmares;
    final titulos = palmares.isEmpty
        ? const [
            Text(
              'Todavía no hay títulos registrados.',
              style: TextStyle(color: AppColores.textoSecundario),
            ),
          ]
        : _porTemporada<RegistroCampeon>(
            palmares,
            (r) => r.temporada,
            _tarjetaTitulo,
          );
    return titulos;
  }

  /// Premios agrupados por temporada.
  List<Widget> _seccionesPremios() {
    final premios = motor.estado!.premios;
    if (premios.isEmpty) {
      return const [
        Text(
          'Todavía no se han entregado premios.',
          style: TextStyle(color: AppColores.textoSecundario),
        ),
      ];
    }
    return _porTemporada<PremioIndividual>(
      premios,
      (p) => p.temporada,
      _tarjetaPremio,
    );
  }

  /// Agrupa una lista por temporada descendente y arma las tarjetas.
  List<Widget> _porTemporada<T>(
    List<T> elementos,
    int Function(T) temporada,
    Widget Function(T) constructor,
  ) {
    // Agrupa en una sola pasada: antes se recorría toda la lista por cada
    // temporada (O(n²), M10).
    final porTemporada = <int, List<T>>{};
    for (final elemento in elementos) {
      porTemporada.putIfAbsent(temporada(elemento), () => []).add(elemento);
    }
    final temporadas = porTemporada.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final widgets = <Widget>[];
    for (final t in temporadas) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            'Temporada $t',
            style: const TextStyle(
              color: AppColores.acento2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      widgets.addAll(porTemporada[t]!.map(constructor));
    }
    return widgets;
  }

  Widget _tarjetaTitulo(RegistroCampeon r) {
    final ganador = motor.equipoPorId(r.ganadorId);
    return Card(
      child: ListTile(
        leading: ganador != null
            ? EscudoEquipo(equipo: ganador, tamano: 36)
            : const Icon(Icons.emoji_events, color: AppColores.dorado),
        title: Row(
          children: [
            Flexible(
              child: Text(
                ganador?.nombre ?? r.ganadorId,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColores.textoPrincipal),
              ),
            ),
            if (r.tipo == TipoCampeon.torneo) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.emoji_events,
                color: AppColores.dorado,
                size: 16,
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${r.descripcion} · ${r.juego.corto}',
          style: const TextStyle(
            color: AppColores.textoSecundario,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          r.tipo == TipoCampeon.torneo ? Icons.public : Icons.sports_esports,
          color: AppColores.textoSecundario,
          size: 18,
        ),
      ),
    );
  }

  Widget _tarjetaPremio(PremioIndividual p) {
    final jugador = p.jugadorId == null
        ? null
        : motor.jugadorPorId(p.jugadorId!);
    final titulo = p.categoria == CategoriaPremio.agenteDelAnio
        ? (p.nombreAgente ?? 'Tu agencia')
        // El nick guardado en el premio sobrevive a la retirada del jugador.
        : (jugador?.nick ?? p.nombreJugador ?? 'Jugador retirado');
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.emoji_events,
          color: AppColores.dorado,
          size: 24,
        ),
        title: Text(
          nombreCategoriaPremio(p.categoria),
          style: const TextStyle(color: AppColores.textoPrincipal),
        ),
        subtitle: Text(
          '${p.juego == null ? 'Global' : p.juego!.corto} · $titulo\n'
          '${p.detalle}',
          style: const TextStyle(
            color: AppColores.textoSecundario,
            fontSize: 12,
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}
