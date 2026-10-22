# Plan de la Fase 1 — ESPORTS AGENT

He leído completo el `PLAN.md`. Estamos en Fase 1, carpeta vacía salvo el propio `PLAN.md`, y Flutter 3.47.7 está instalado.

Aquí está el plan de archivos para la **Fase 1** (crear + modificar). No se escribe nada hasta que se apruebe.

## 0. Preparación del proyecto (comandos)
- Ampliar el árbol con `flutter create --project-name esports_agent --platforms=linux,android .` → genera `pubspec.yaml`, `lib/main.dart` temporal, `linux/`, `android/`.
- **Paquete externo (permiso, regla 4):** `shared_preferences` — sirve para guardar la partida en el disco. Es el único permitido en Fase 1.
- No se descargan imágenes; los escudos los pone el usuario.

## 1. Archivos raíz
| Archivo | Qué hace |
|---|---|
| `pubspec.yaml` *(modificar)* | Agrega `shared_preferences` y declara `assets/escudos/`. |
| `assets/escudos/LEEME.txt` | Explica cómo nombrar los escudos (ej: `t1.png`, `fnatic.png`). |

## 2. Modelos (`lib/modelos/`)
| Archivo | Qué hace |
|---|---|
| `juego.dart` | Enum `Juego` (LoL, Valorant, CS2, Dota 2) con sus 5 roles y nombre para mostrar. |
| `jugador.dart` | Modelo de jugador (campos de la sección 5.1) + `toJson`/`fromJson`. |
| `equipo.dart` | Modelo de equipo (5.2, incluye `escudo`) + JSON. |
| `agente.dart` | Modelo del agente (5.3) + JSON. |
| `noticia.dart` | Modelo de noticia (5.4) con su enum de tipo. |
| `estado_partida.dart` | Contenedor global: agente, jugadores, equipos, noticias, semana, temporada, ofertas/negociaciones + JSON (con `"version": 1`). |

## 3. Datos iniciales (`lib/datos/`)
| Archivo | Qué hace |
|---|---|
| `equipos_iniciales.dart` | Los 24 equipos reales (6 por juego) con prestigio/presupuesto/color; comentario de cabecera. |
| `jugadores_iniciales.dart` | Plantillas reales (5 por equipo), marcados `// VERIFICAR`; relleno dudoso con generador. |
| `nombres_aleatorios.dart` | Listas de nombres, nicks y países para generar jóvenes. |

## 4. Lógica (`lib/logica/`)
| Archivo | Qué hace |
|---|---|
| `formulas.dart` | Constantes + valor de mercado, salario, comisiones, aceptación, progreso, etc. (sección 7). |
| `generador_jugadores.dart` | Crea jugadores jóvenes aleatorios (libres y nuevos talentos). |
| `negociacion.dart` | Lógica de ofertas/respuestas/contraofertas y cierre de trato (7.5). |
| `motor_juego.dart` | **`ChangeNotifier` principal**: estado, reclutar, ofrecer, avanzar semana, temporada, bancarrota, noticias, autoguardado. |

## 5. Servicios (`lib/servicios/`)
| Archivo | Qué hace |
|---|---|
| `guardado.dart` | `guardarPartida`, `cargarPartida`, `existePartida`, `borrarPartida` con `shared_preferences` + JSON. |

## 6. Interfaz (`lib/pantallas/`)
| Archivo | Qué hace |
|---|---|
| `pantalla_inicio.dart` | Logo, botones Nueva partida / Continuar (con confirmación). |
| `pantalla_crear_agente.dart` | Nombre + país → empieza con $50.000 y rep. 10. |
| `pantalla_principal.dart` | Barra superior fija, 5 pestañas y botón "Avanzar semana". |
| `pestana_resumen.dart` | Dinero, reputación, top 3 y últimas noticias. |
| `pestana_mis_jugadores.dart` | Lista de jugadores que represento. |
| `pestana_mercado.dart` | Filtros (juego/orden/libres-todos) y lista. |
| `pestana_equipos.dart` | Lista de equipos filtrable por juego. |
| `pestana_noticias.dart` | Noticias cronológicas con color por tipo. |
| `pantalla_detalle_jugador.dart` | Ficha completa + botones Reclutar / Ofrecer / Dejar de representar. |
| `pantalla_detalle_equipo.dart` | Ficha del equipo + plantilla de 5. |
| `pantalla_negociacion.dart` | Elegir equipo, interés, precio, respuesta y rondas restantes. |
| `pantalla_ajustes.dart` | Datos del agente + Borrar partida (doble confirmación). |

## 7. Widgets (`lib/widgets/`)
| Archivo | Qué hace |
|---|---|
| `escudo_equipo.dart` | Carga `assets/escudos/<escudo>.png`; si falla, círculo con color + iniciales. |
| `tarjeta_jugador.dart` | Tarjeta resumen de un jugador. |
| `barra_habilidad.dart` | Barra con color según el valor. |
| `indicador_dinero.dart` | Formatea dinero "$1.250.000" (rojo si negativo). |
| `dialogo_confirmacion.dart` | Diálogo Cancelar / Confirmar reutilizable. |

## 8. Otros
- `lib/tema/tema_app.dart` — colores/estilos oscuros (sección 10) y Material 3.
- `lib/main.dart` *(modificar)* — punto de entrada: inicializa y muestra la pantalla de inicio.

**Orden de trabajo:** modelos → datos → fórmulas/generador → motor → guardado → tema/widgets → pantallas. Al final: `flutter analyze`, `flutter run -d linux` y se explica cómo probar cada punto de la sección 13.
