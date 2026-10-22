// Tarjeta que resume a un jugador. Se usa en el mercado y en otras listas.
import 'package:flutter/material.dart';

import '../logica/formulas.dart';
import '../modelos/equipo.dart';
import '../modelos/jugador.dart';
import '../tema/tema_app.dart';
import 'barra_habilidad.dart';
import 'escudo_equipo.dart';
import 'estrellas_forma.dart';

/// Tarjeta con el nick, rol, edad, habilidad, valor y escudo del jugador.
class TarjetaJugador extends StatelessWidget {
  const TarjetaJugador({
    super.key,
    required this.jugador,
    this.equipo,
    this.onTap,
  });

  final Jugador jugador;

  /// Equipo actual del jugador (null si es agente libre).
  final Equipo? equipo;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Escudo del equipo o círculo "libre".
              if (equipo != null)
                EscudoEquipo(equipo: equipo!, tamano: 44)
              else
                const _CirculoLibre(),
              const SizedBox(width: 12),
              // Datos del jugador.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            jugador.nick,
                            style: const TextStyle(
                              color: AppColores.textoPrincipal,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (jugador.estaInactivo)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.medical_services,
                              color: AppColores.peligro,
                              size: 18,
                            ),
                          ),
                        if (jugador.representadoPorMi)
                          const Icon(
                            Icons.star,
                            color: AppColores.dorado,
                            size: 18,
                          ),
                      ],
                    ),
                    Text(
                      '${jugador.rol} · ${jugador.edad} años · ${jugador.pais}',
                      style: const TextStyle(
                        color: AppColores.textoSecundario,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    BarraHabilidad(valor: jugador.habilidad),
                    const SizedBox(height: 4),
                    EstrellasForma(
                      estrellas: estrellasDeNotas(jugador.ultimasNotas),
                      tamano: 13,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Valor de mercado.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Valor',
                    style: TextStyle(
                      color: AppColores.textoSecundario,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    formatearDinero(jugador.valorMercado),
                    style: const TextStyle(
                      color: AppColores.acento2,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Círculo gris que representa a un agente libre.
class _CirculoLibre extends StatelessWidget {
  const _CirculoLibre();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Colors.white10,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_outline,
        color: AppColores.textoSecundario,
        size: 22,
      ),
    );
  }
}
