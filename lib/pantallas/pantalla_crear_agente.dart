// Pantalla para crear el agente: nombre y país.
import 'package:flutter/material.dart';

import '../datos/nombres_aleatorios.dart';
import '../logica/motor_juego.dart';
import '../tema/tema_app.dart';
import 'pantalla_principal.dart';

class PantallaCrearAgente extends StatefulWidget {
  const PantallaCrearAgente({super.key, required this.motor});

  final MotorJuego motor;

  @override
  State<PantallaCrearAgente> createState() => _PantallaCrearAgenteState();
}

class _PantallaCrearAgenteState extends State<PantallaCrearAgente> {
  final TextEditingController _nombre = TextEditingController();
  String _pais = paisesAgente.first;

  /// Evita que dos toques seguidos en "Empezar carrera" lancen dos partidas
  /// concurrentes (M12).
  bool _creando = false;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _empezar() async {
    if (_creando) return;
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre para tu agente.')),
      );
      return;
    }
    setState(() => _creando = true);
    try {
      // `nuevaPartida` sobrescribe el guardado anterior solo al terminar de
      // crear la partida nueva. Si algo falla, se puede volver atrás sin
      // haber perdido la partida vieja (I13).
      await widget.motor.nuevaPartida(nombre: nombre, pais: _pais);
    } finally {
      if (mounted) setState(() => _creando = false);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PantallaPrincipal(motor: widget.motor)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear agente')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¿Cómo te llamas?',
              style: TextStyle(color: AppColores.textoSecundario),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Nombre del agente'),
            ),
            const SizedBox(height: 20),
            const Text(
              '¿De qué país eres?',
              style: TextStyle(color: AppColores.textoSecundario),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _pais,
              dropdownColor: AppColores.superficie,
              items: paisesAgente
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (valor) {
                if (valor != null) setState(() => _pais = valor);
              },
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _creando ? null : _empezar,
              child: Text(_creando ? 'Creando…' : 'Empezar carrera'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Empiezas con \$50.000 y 10 de reputación.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColores.textoSecundario, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
