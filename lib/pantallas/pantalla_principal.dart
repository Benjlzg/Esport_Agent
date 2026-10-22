// Pantalla principal: barra superior, 5 pestañas y el botón avanzar semana.
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../logica/motor_juego.dart';
import '../tema/tema_app.dart';
import '../widgets/indicador_dinero.dart';
import 'pantalla_ajustes.dart';
import 'pantalla_ceremonia_premios.dart';
import 'pantalla_competicion.dart';
import 'pantalla_eventos.dart';
import 'pantalla_inicio.dart';
import 'pantalla_ofertas.dart';
import 'pestana_equipos.dart';
import 'pestana_mercado.dart';
import 'pestana_mis_jugadores.dart';
import 'pestana_resumen.dart';

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key, required this.motor});

  final MotorJuego motor;

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indice = 0;

  /// Evita abrir dos veces la misma tanda de eventos.
  bool _mostrandoEventos = false;

  @override
  void initState() {
    super.initState();
    // Al entrar (por ejemplo al pulsar "Continuar"), muestra los eventos que
    // se guardaron pendientes de la sesión anterior.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mostrarEventosPendientes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.motor,
      builder: (context, _) {
        // Si no hay partida (por ejemplo, después de borrarla), se muestra el
        // inicio en vez de leer getters que necesitan el estado (C2).
        if (!widget.motor.hayPartida) {
          return PantallaInicio(motor: widget.motor);
        }
        // Si el juego terminó por bancarrota, muestro la pantalla final.
        if (widget.motor.finDelJuego) {
          return _PantallaFinDelJuego(motor: widget.motor);
        }

        final pestanas = [
          PestanaResumen(motor: widget.motor),
          PestanaMisJugadores(motor: widget.motor),
          PestanaMercado(motor: widget.motor),
          PestanaEquipos(motor: widget.motor),
          PantallaCompeticion(motor: widget.motor),
        ];

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _BarraSuperior(
                  motor: widget.motor,
                  onAvanzarDiez: _avanzarDiezSemanas,
                ),
                Expanded(
                  child: IndexedStack(index: _indice, children: pestanas),
                ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _indice,
            onDestinationSelected: (i) => setState(() => _indice = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Resumen',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups),
                label: 'Mi agencia',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: 'Mercado',
              ),
              NavigationDestination(
                icon: Icon(Icons.shield_outlined),
                selectedIcon: Icon(Icons.shield),
                label: 'Equipos',
              ),
              NavigationDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events),
                label: 'Competición',
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            // Mientras se procesa un avance, el botón queda deshabilitado
            // para que un doble toque no avance dos semanas (I5).
            onPressed: widget.motor.avanzando ? null : _avanzarSemana,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Avanzar semana'),
          ),
        );
      },
    );
  }

  Future<void> _avanzarSemana() async {
    await widget.motor.avanzarSemana();
    if (!mounted) return;
    await _mostrarEventosPendientes();
    if (!mounted) return;
    await _mostrarCeremoniaSiPendiente();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Avanzaste a la temporada ${widget.motor.temporada} · semana ${widget.motor.semana}.',
        ),
      ),
    );
  }

  /// Atajo de depuración: avanza 10 semanas de golpe.
  Future<void> _avanzarDiezSemanas() async {
    await widget.motor.avanzarSemanas(10);
    if (!mounted) return;
    await _mostrarEventosPendientes();
    if (!mounted) return;
    await _mostrarCeremoniaSiPendiente();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Avanzaste 10 semanas: temporada ${widget.motor.temporada} · semana ${widget.motor.semana}.',
        ),
      ),
    );
  }

  /// Muestra los eventos pendientes (decisiones e informativos que no se
  /// hayan resuelto antes). No hace nada si no hay eventos o si ya están
  /// abiertos.
  Future<void> _mostrarEventosPendientes() async {
    if (_mostrandoEventos || !mounted) return;
    if (widget.motor.eventosPendientes.isEmpty) return;
    _mostrandoEventos = true;
    try {
      await mostrarEventosPendientes(context, widget.motor);
    } finally {
      _mostrandoEventos = false;
    }
  }

  /// Abre la ceremonia de premios si el motor la dejó pendiente y la marca
  /// como vista al cerrarla.
  Future<void> _mostrarCeremoniaSiPendiente() async {
    if (!widget.motor.ceremoniaPendiente) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaCeremoniaPremios(motor: widget.motor),
      ),
    );
    await widget.motor.ceremoniaVista();
  }
}

/// Barra superior fija: dinero, reputación, temporada/semana y ajustes.
class _BarraSuperior extends StatelessWidget {
  const _BarraSuperior({required this.motor, this.onAvanzarDiez});

  final MotorJuego motor;

  /// Atajo de depuración para avanzar 10 semanas (solo en kDebugMode).
  final VoidCallback? onAvanzarDiez;

  @override
  Widget build(BuildContext context) {
    final agente = motor.agente;
    final ofertas = motor.ofertasPendientes.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      color: AppColores.fondo,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IndicadorDinero(monto: agente.dinero, tamanoFuente: 18),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: AppColores.dorado),
                    const SizedBox(width: 4),
                    Text(
                      'Reputación ${agente.reputacion}',
                      style: const TextStyle(
                        color: AppColores.textoSecundario,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Temp. ${motor.temporada} · Sem ${motor.semana}',
                      style: const TextStyle(
                        color: AppColores.acento2,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  motor.etapaActual.nombre,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColores.textoPrincipal,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (kDebugMode && onAvanzarDiez != null)
            IconButton(
              tooltip: 'Avanzar 10 semanas',
              icon: const Icon(Icons.fast_forward),
              onPressed: motor.avanzando ? null : onAvanzarDiez,
            ),
          IconButton(
            tooltip: 'Ofertas pendientes',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PantallaOfertas(motor: motor),
                ),
              );
            },
            icon: ofertas == 0
                ? const Icon(Icons.mail_outline)
                : Badge.count(
                    count: ofertas,
                    backgroundColor: AppColores.peligro,
                    child: const Icon(Icons.mail),
                  ),
          ),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PantallaAjustes(motor: motor),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Pantalla que aparece cuando el juego termina por bancarrota.
class _PantallaFinDelJuego extends StatelessWidget {
  const _PantallaFinDelJuego({required this.motor});

  final MotorJuego motor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.sentiment_very_dissatisfied,
                size: 72,
                color: AppColores.peligro,
              ),
              const SizedBox(height: 16),
              const Text(
                'Fin del juego',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColores.peligro,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tu agencia no pudo recuperarse y terminó en bancarrota.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColores.textoSecundario),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () async {
                  await motor.borrar();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => PantallaInicio(motor: motor),
                    ),
                    (route) => false,
                  );
                },
                child: const Text('Empezar de nuevo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
