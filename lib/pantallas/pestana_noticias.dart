// Pestaña de noticias: lista cronológica con la más reciente arriba.
import 'package:flutter/material.dart';

import '../logica/motor_juego.dart';
import '../modelos/noticia.dart';
import '../tema/tema_app.dart';

/// Devuelve el ícono y color de cada tipo de noticia.
({IconData icono, Color color}) _estiloNoticia(TipoNoticia tipo) {
  switch (tipo) {
    case TipoNoticia.fichaje:
      return (icono: Icons.person_add, color: AppColores.acento2);
    case TipoNoticia.venta:
      return (icono: Icons.attach_money, color: AppColores.exito);
    case TipoNoticia.progreso:
      return (icono: Icons.trending_up, color: AppColores.exito);
    case TipoNoticia.dinero:
      return (icono: Icons.payments, color: AppColores.dorado);
    case TipoNoticia.evento:
      return (icono: Icons.newspaper, color: AppColores.textoSecundario);
    case TipoNoticia.alerta:
      return (icono: Icons.warning_amber, color: AppColores.peligro);
  }
}

/// Fila que muestra una noticia (se reutiliza en el resumen).
class FilaNoticia extends StatelessWidget {
  const FilaNoticia({super.key, required this.noticia});

  final Noticia noticia;

  @override
  Widget build(BuildContext context) {
    final estilo = _estiloNoticia(noticia.tipo);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(estilo.icono, color: estilo.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  noticia.texto,
                  style: const TextStyle(
                    color: AppColores.textoPrincipal,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Temporada ${noticia.temporada} · Semana ${noticia.semana}',
                  style: const TextStyle(
                    color: AppColores.textoSecundario,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PestanaNoticias extends StatelessWidget {
  const PestanaNoticias({super.key, required this.motor});

  final MotorJuego motor;

  @override
  Widget build(BuildContext context) {
    final noticias = motor.noticias;
    if (noticias.isEmpty) {
      return const Center(
        child: Text(
          'Todavía no hay noticias.',
          style: TextStyle(color: AppColores.textoSecundario),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: noticias.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => FilaNoticia(noticia: noticias[i]),
    );
  }
}
