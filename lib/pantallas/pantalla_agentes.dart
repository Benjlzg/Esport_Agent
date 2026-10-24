// Ranking de agentes (Parte 3A): rivales y mi agencia en la misma tabla.
//
// Se puede usar como pantalla completa o como vista dentro de Mi agencia.
// La barra inferior sigue teniendo 5 pestañas: no se añade una nueva.
import 'package:flutter/material.dart';

import '../logica/agentes_rivales.dart';
import '../logica/formulas.dart';
import '../logica/motor_juego.dart';
import '../modelos/agente_rival.dart';
import '../tema/tema_app.dart';
import 'pantalla_detalle_agente_rival.dart';

/// Icono que representa visualmente a cada perfil de agente.
IconData iconoDePerfil(PerfilRival? perfil) {
  switch (perfil) {
    case PerfilRival.agresivo:
      return Icons.trending_up;
    case PerfilRival.cazatalentos:
      return Icons.travel_explore;
    case PerfilRival.negociador:
      return Icons.handshake;
    case PerfilRival.comercial:
      return Icons.storefront;
    case PerfilRival.conservador:
      return Icons.shield_outlined;
    case PerfilRival.especialista:
      return Icons.sports_esports;
    case null:
      return Icons.person;
  }
}

/// Vista con el ranking completo de agentes. Mi fila va resaltada en violeta.
class VistaAgentes extends StatelessWidget {
  const VistaAgentes({super.key, required this.motor});

  final MotorJuego motor;

  @override
  Widget build(BuildContext context) {
    final filas = motor.rankingAgentes;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, margenBotonAvanzarSemana),
      itemCount: filas.length + 1,
      itemBuilder: (context, indice) {
        if (indice == 0) return _encabezado(filas.length);
        final fila = filas[indice - 1];
        return _filaRanking(context, fila, indice);
      },
    );
  }

  /// Cabecera con una explicación corta del ranking.
  Widget _encabezado(int cantidad) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ranking de agentes',
                style: TextStyle(
                  color: AppColores.textoPrincipal,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tú y $cantidad agentes rivales. Los puntos combinan '
                'reputación y valor de cartera; los desempates van por cartera.',
                style: const TextStyle(
                  color: AppColores.textoSecundario,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Una fila del ranking, con mi agencia resaltada.
  Widget _filaRanking(
    BuildContext context,
    FilaRankingAgente fila,
    int posicion,
  ) {
    final colorFondo = fila.esYo
        ? AppColores.acento.withValues(alpha: 0.18)
        : AppColores.superficie;
    final borde = fila.esYo
        ? Border.all(color: AppColores.acento, width: 1.2)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colorFondo,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: fila.esYo
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PantallaDetalleAgenteRival(
                        motor: motor,
                        agenteId: fila.rivalId!,
                      ),
                    ),
                  );
                },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: borde,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '$posicion',
                    style: TextStyle(
                      color: fila.esYo
                          ? AppColores.acento2
                          : AppColores.textoSecundario,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: fila.esYo
                      ? AppColores.acento
                      : Colors.white10,
                  child: Icon(
                    iconoDePerfil(fila.perfil),
                    color: fila.esYo
                        ? AppColores.textoPrincipal
                        : AppColores.acento2,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fila.esYo ? '${fila.nombre} (tú)' : fila.nombre,
                        style: const TextStyle(
                          color: AppColores.textoPrincipal,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        fila.perfil?.etiqueta ?? 'Tu agencia',
                        style: const TextStyle(
                          color: AppColores.textoSecundario,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${fila.reputacion} reputación · '
                        '${fila.representados} representados',
                        style: const TextStyle(
                          color: AppColores.textoSecundario,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${fila.puntos} pts',
                      style: const TextStyle(
                        color: AppColores.dorado,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      formatearDinero(fila.valorCartera),
                      style: const TextStyle(
                        color: AppColores.acento2,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla completa del ranking. Se usa cuando se abre desde fuera de la
/// subpestaña de Mi agencia.
class PantallaAgentes extends StatelessWidget {
  const PantallaAgentes({super.key, required this.motor});

  final MotorJuego motor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agentes')),
      body: ListenableBuilder(
        listenable: motor,
        builder: (context, _) => VistaAgentes(motor: motor),
      ),
    );
  }
}
