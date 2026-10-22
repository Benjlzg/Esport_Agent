# PLAN PARTE 2C — TORNEOS INTERNACIONALES, PREMIOS Y ASCENSOS

> Documento de trabajo para OpenCode. Guarda el plan aprobado antes de programar.
> Basado en `PLAN.md` (sección 0) y `PLAN_FASE2.md` (Parte 2C).
> Se implementa SOLO la Parte 2C. Nada de 2D ni 2E.

---

## 1. OBJETIVO

Que el calendario internacional cobre vida: **Torneo de Mitad de Temporada**
(semanas 21–22) y **Mundial/Major** (semanas 43–46), con clasificados,
brackets, premios en dinero, efectos sobre los jugadores representados,
**ascensos y descensos**, **Palmarés histórico** y **ceremonia de premios
individuales**.

Hoy las semanas 21–22 y 43–46 existen como etapas del calendario
(`TipoEtapa.internacional`/`mundial`) pero **no se simulan** (ver
`calendario.dart` y `motor_juego.dart`). Quedan **fuera** de esta parte el
mercado vivo (2D) y los eventos aleatorios (2E).

---

## 2. DECISIONES APROBADAS

1. **Versión del guardado → `4`** (nuevos campos: torneos, palmarés y premios).
   Las partidas de la versión 3 se consideran incompatibles y muestran el aviso
   ya existente (con botón "Empezar de nuevo").
2. **Clasificación:**
   - **Mitad de Temporada:** campeón del Split 1 de **1ª División** de cada
     región.
   - **Mundial:** **los 2 mejores** de cada región de 1ª División por **puntos
     sumados de Split 1 + Split 2**.
   - Regiones por videojuego: LoL 7, Valorant 5, CS2 4, Dota 2 7.
3. **Brackets:** eliminación directa; si el número no es potencia de 2, los de
   **mayor prestigio reciben bye**. El Mundial empieza con fase de grupos
   (grupos de 3–4, todos contra todos, Bo1) y los 2 mejores de cada grupo pasan
   a eliminación directa Bo5. El torneo de mitad de temporada es Bo5 en todas
   las rondas.
4. **Ascenso/descenso:** baja el **último de la 1ª División** (tabla sumada de
   ambos splits); sube el **campeón del Split 2 de la 2ª División**. Se aplica
   al **cerrar la temporada** (rollover 52→1), que es el fin real de la ventana
   47–52. Prestigio ±8 (clamp 1–100) y presupuesto = prestigio × 20.000.
5. **Premios individuales** entregados **por videojuego**, salvo **Agente del
   Año**, que es único de la temporada.
6. **Interfaz:** `PantallaCompeticion` pasa a tener 3 segmentos
   (**Calendario | Ligas | Torneos**); el **Palmarés** se abre con un botón
   desde Torneos. La **ceremonia** se muestra automáticamente al avanzar a la
   semana 47.
7. **Reparto de premios** (el dinero va al presupuesto del equipo):
   - Mitad de Temporada ($500.000): campeón 50% · finalista 25% ·
     semifinalistas 12,5% cada uno.
   - Mundial ($2.000.000): campeón 40% · finalista 20% · semifinalistas 10% cada
     uno · cuartos de final 5% cada uno.

---

## 3. MODELOS NUEVOS

### 3.1 `lib/modelos/torneo.dart`

- `enum TipoTorneo { mitad, mundial }`.
- `Torneo`:
  - `id`, `tipo`, `juego` (Juego), `temporada`, `nombre` ("Torneo de Mitad de
    Temporada" / "Mundial"; en CS2 el Mundial se llama "Major").
  - `participantes` (`List<String>` de ids, orden por prestigio).
  - `grupos` (`Map<String, List<String>>?`, solo en el Mundial; vacío en la
    eliminación directa).
  - `rondas` (`List<List<ResultadoSerie>>`: reutiliza el modelo de
    `partido.dart`; cada ronda se etiqueta en `ResultadoSerie.etapa`, ej.
    "Grupo A", "Cuartos", "Semifinal", "Final").
  - Getters: `campeonId`, `subcampeonId`, `rondasJugadas`, `todosLosResultados`.
  - `toJson()` / `fromJson()`.

### 3.2 `lib/modelos/historial.dart`

- `enum TipoCampeon { liga, torneo }`.
- `enum CategoriaPremio { jugadorDelAnio, maximoEliminador, revelacion,
  equipoIdeal, agenteDelAnio }`.
- `RegistroCampeon`: `temporada`, `juego`, `descripcion` (ej. "Liga Coreana
  (Split 1)"), `tipo`, `ganadorId`.
- `PremioIndividual`: `temporada`, `juego?`, `categoria`, `jugadorId?`, `rol?`,
  `detalle` (texto), `nombreAgente?` (para Agente del Año).
- Ambos con `toJson()` / `fromJson()`.

---

## 4. MODELOS MODIFICADOS

- `lib/modelos/estado_partida.dart`: campos `torneos` (`List<Torneo>`),
  `palmares` (`List<RegistroCampeon>`), `premios` (`List<PremioIndividual>`),
  `ceremoniaPendiente` (`bool`); subir `versionFormato` a **4**; serialización
  tolerante a campos ausentes.
- `lib/modelos/equipo.dart`: sin cambios de estructura (los títulos se derivan
  del palmarés).

---

## 5. LÓGICA NUEVA

### 5.1 Refactor de `lib/logica/simulador_partidos.dart`

- `simularSerie` recibe **`mapasParaGanar`** (1 = Bo1, 2 = Bo3, 3 = Bo5) en vez
  de derivarlo solo de `esPlayoffs` (se conserva `esPlayoffs` como valor por
  defecto para no romper la Parte 2B).
- Exponer un helper público
  `simularEnfrentamiento({local, visitante, plantillas, etapa, mapasParaGanar,
  rivales, rnd})` reutilizable por liga y torneos.
- `lib/logica/liga.dart`: su `_simularEnfrentamiento` privado pasa a llamar al
  helper compartido.

### 5.2 `lib/logica/torneos.dart`

- `clasificadosMitad(estado, juego)` → campeones del Split 1 (1ª División).
- `clasificadosMundial(estado, juego)` → 2 mejores por región por puntos
  sumados de ambos splits.
- `crearTorneoMitad(...)` / `crearTorneoMundial(...)`: arman participantes y
  grupos.
- `construirBracket(idsOrdenados)`: rondas con byes para los mejores.
- `avanzarTorneoMitad(torneo, ...)`: semana 21 juega rondas hasta dejar 2;
  semana 22 la final.
- `avanzarTorneoMundial(torneo, ...)`: semana 43 grupos (Bo1); semanas 44–46
  una ronda de eliminación Bo5 por semana.
- `repartirPremios(torneo, equipos)`: suma al presupuesto según la colocación.
- `aplicarEfectosCampeon(torneo, jugadores, agente)`: por cada representado del
  equipo campeón → bono (al jugador, sin tocar mi dinero), moral +15,
  `multiplicadorValor × 1,10`; reputación +2 (mitad) / +5 (Mundial); noticia en
  dorado.

### 5.3 `lib/logica/ascensos.dart`

- `procesarAscensosYDescensos(estado)`: por cada región + videojuego, el último
  de 1ª (tabla sumada) baja y el campeón del Split 2 de 2ª sube; cambia
  `division`, `liga` (derivada de la región + división), prestigio ±8
  (clamp 1–100) y recalcula el presupuesto. Devuelve las noticias; después el
  motor reconstruye `competiciones`.

### 5.4 `lib/logica/premios.dart`

- `calcularPremios(estado, juego, titulosPorJugador)`:
  - **Jugador del Año:** `notaPromedio × 10 + títulos (Mundial 15, mitad 8,
    liga 5) + MVPs × 0,5`; mínimo 20 series jugadas.
  - **Máximo Eliminador:** más eliminaciones de la temporada; en LoL y Dota 2
    solo cuentan los roles Carry/ADC/Mid.
  - **Revelación del Año:** mejor puntaje entre jugadores de 20 años o menos.
  - **Mejor Equipo Ideal:** mejor `promedioNota` por rol.
  - **Agente del Año** (global): lo gano si el total de títulos de mis
    representados supera el de cualquier equipo; da reputación +5.
- `aplicarEfectosPremios(...)`: a mis premiados → valor +15%, moral +20,
  reputación +3.

---

## 6. CONSTANTES NUEVAS

Van en `lib/logica/formulas.dart` (o en el archivo de su lógica), con nombre y
comentadas, para ajustar el balance fácilmente:

- Montos totales y porcentajes de reparto de cada torneo.
- Premios de títulos para el puntaje del Jugador del Año (Mundial 15, mitad 8,
  liga 5).
- Umbral de 20 series para los premios individuales.
- Efectos de bonificación (moral, multiplicador de valor y reputación).

---

## 7. MOTOR (`lib/logica/motor_juego.dart`)

- `_simularEtapaActual`: semanas 21–22 → avanzar el torneo de mitad (creándolo
  si no existe); semanas 43–46 → avanzar el Mundial.
- Al decidirse un campeón de liga o torneo → registrarlo en `palmares`
  (además de `campeonesTemporada`).
- Semana 47: calcular los premios individuales una sola vez (flag), guardarlos
  en `premios` y poner `ceremoniaPendiente = true`.
- `_nuevaTemporada`: **antes** de reiniciar competiciones, ejecutar
  `procesarAscensosYDescensos` y reconstruir `competiciones` con
  `_crearCompeticiones`; reiniciar torneos y `ceremoniaPendiente`.
- Consultas nuevas: `torneosDeTemporada`, `palmaresDeJuego`,
  `titulosDeEquipo`, `premiosDeJugador`, getter `ceremoniaPendiente` y acción
  `ceremoniaVista()`.

---

## 8. INTERFAZ

- `pantalla_competicion.dart`: 3er segmento **Torneos**.
- **Nueva** `pestana_torneos.dart`: torneos de la temporada (grupos/bracket,
  resultados por ronda, campeón y premios) + botón **Palmarés**.
- **Nueva** `pantalla_palmares.dart`: campeones por temporada (ligas y torneos)
  y premios individuales.
- **Nueva** `pantalla_ceremonia_premios.dart`: los ganadores uno tras otro
  (PageView) con botón de avance.
- `pantalla_principal.dart`: tras `avanzarSemana`, si `ceremoniaPendiente`,
  abrir la ceremonia y llamar a `ceremoniaVista()`.
- `pantalla_detalle_equipo.dart`: sección **Títulos** (derivada del palmarés).
- `pantalla_detalle_jugador.dart`: sección **Premios** con íconos 🏆.
- `pestana_resumen.dart`: noticia destacada del último campeón internacional
  (opcional).

---

## 9. ARCHIVOS A CREAR

- `PLAN_2C.md` (este documento)
- `lib/modelos/torneo.dart`
- `lib/modelos/historial.dart`
- `lib/logica/torneos.dart`
- `lib/logica/ascensos.dart`
- `lib/logica/premios.dart`
- `lib/pantallas/pestana_torneos.dart`
- `lib/pantallas/pantalla_palmares.dart`
- `lib/pantallas/pantalla_ceremonia_premios.dart`

---

## 10. ARCHIVOS A MODIFICAR

| Archivo | Cambio |
|---|---|
| `lib/logica/simulador_partidos.dart` | `mapasParaGanar` (Bo1/3/5) + helper compartido. |
| `lib/logica/liga.dart` | Usar el helper compartido. |
| `lib/logica/formulas.dart` | Constantes de premios. |
| `lib/modelos/estado_partida.dart` | Torneos, palmarés, premios, ceremonia; versión 4. |
| `lib/servicios/guardado.dart` | Hereda el aviso de versión (sin cambios de lógica). |
| `lib/logica/motor_juego.dart` | Simular torneos, palmarés, premios, ascensos y consultas. |
| `lib/pantallas/pantalla_competicion.dart` | Segmento Torneos. |
| `lib/pantallas/pantalla_principal.dart` | Disparar la ceremonia. |
| `lib/pantallas/pantalla_detalle_equipo.dart` | Títulos. |
| `lib/pantallas/pantalla_detalle_jugador.dart` | Premios. |
| `lib/pantallas/pestana_resumen.dart` | Campeón destacado (opcional). |

---

## 11. ORDEN DE TRABAJO

1. Crear `lib/modelos/torneo.dart`.
2. Crear `lib/modelos/historial.dart`.
3. Ampliar `lib/modelos/estado_partida.dart` (torneos, palmarés, premios y
   ceremonia) y subir `versionFormato` a **4**.
4. Añadir las constantes de premios a `lib/logica/formulas.dart`.
5. Refactorizar `lib/logica/simulador_partidos.dart` (`mapasParaGanar` + helper
   público) y adaptar `lib/logica/liga.dart`.
6. Crear `lib/logica/torneos.dart` (clasificación, bracket, grupos, rondas y
   reparto de premios).
7. Crear `lib/logica/ascensos.dart`.
8. Crear `lib/logica/premios.dart`.
9. Integrar todo en `lib/logica/motor_juego.dart` (semanas 21–22 y 43–46,
   palmarés, semana 47, ascensos en `_nuevaTemporada`, consultas y
   `ceremoniaVista`).
10. Crear `lib/pantallas/pestana_torneos.dart`.
11. Crear `lib/pantallas/pantalla_palmares.dart`.
12. Crear `lib/pantallas/pantalla_ceremonia_premios.dart`.
13. Modificar `lib/pantallas/pantalla_competicion.dart` (segmento Torneos).
14. Modificar `lib/pantallas/pantalla_principal.dart` (mostrar la ceremonia tras
    avanzar).
15. Modificar `lib/pantallas/pantalla_detalle_equipo.dart` (títulos) y
    `pantalla_detalle_jugador.dart` (premios).
16. Ajustar `lib/pantallas/pestana_resumen.dart` si aporta (campeón
    internacional).
17. Ejecutar `flutter analyze` y `flutter test`; corregir todo. Añadir
    `test/torneos_test.dart` con un bracket y un reparto de premios.
18. Ejecutar `flutter run -d linux` y comprobar que abre.
19. Añadir la sección 2C a `PROGRESO.md` con la guía de prueba paso a paso.

---

## 12. PRUEBAS DE LA PARTE 2C

- [ ] Se juega el Torneo de Mitad de Temporada y el Mundial con los
      clasificados correctos.
- [ ] Los premios aparecen en el presupuesto de los equipos.
- [ ] Un representado campeón sube de moral, valor y reputación (noticia
      dorada).
- [ ] Al final de temporada hay ascensos y descensos con prestigio ±8.
- [ ] El Palmarés muestra los campeones por temporada.
- [ ] Hay ceremonia de premios (Jugador del Año, Máximo Eliminador, Revelación,
      Equipo Ideal, Agente del Año).
- [ ] `flutter analyze` no muestra errores.
