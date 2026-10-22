// Muestra el escudo de un equipo. Si no existe la imagen, dibuja un
// círculo con el color del equipo y sus iniciales.
import 'package:flutter/material.dart';

import '../modelos/equipo.dart';

/// Escudo circular de un equipo.
class EscudoEquipo extends StatelessWidget {
  const EscudoEquipo({super.key, required this.equipo, this.tamano = 40});

  final Equipo equipo;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        'assets/escudos/${equipo.escudo}',
        width: tamano,
        height: tamano,
        fit: BoxFit.cover,
        // Si la imagen no existe, muestra el círculo con iniciales.
        errorBuilder: (context, error, stackTrace) => _circuloConIniciales(),
      ),
    );
  }

  Widget _circuloConIniciales() {
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      // Borde gris claro para que los escudos oscuros se distingan del fondo.
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(equipo.colorPrincipal),
        border: Border.all(
          color: const Color(0xFFBDBDBD),
          width: tamano >= 60 ? 1.5 : 1,
        ),
      ),
      child: Text(
        equipo.iniciales,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: tamano * 0.34,
        ),
      ),
    );
  }
}
