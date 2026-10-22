# PLAN PARTE 2B — CALENDARIO, LIGAS Y PARTIDOS

> Documento de trabajo para OpenCode. Guarda el plan aprobado antes de programar.
> Basado en `PLAN.md` (sección 0) y `PLAN_FASE2.md` (Parte 2B).
> Se implementa SOLO la Parte 2B. Nada de 2C, 2D ni 2E.

---

## 1. OBJETIVO

Que cada semana se jueguen partidos reales en todas las ligas
(Videojuego → Región → División), con tablas de posiciones, playoffs,
campeones, estadísticas de jugadores, estado de forma, previsualización de
partidos y rivalidades.

Quedan **fuera** de esta parte: los torneos internacionales y los ascensos y
descensos (Parte 2C), el mercado de la IA y las ventanas de fichajes (Parte 2D)
y los eventos aleatorios (Parte 2E). Esas semanas se muestran en el calendario
como etapas, pero sin simulación propia todavía.

---

## 2. DECISIONES APROBADAS

1. **Versión del guardado:** subir a `"version": 3`. Las partidas de la versión 2
   se consideran incompatibles y muestran el aviso existente (con botón
   "Empezar de nuevo").
2. **Interfaz:** la barra inferior pasa a tener **5 pestañas**: Resumen,
   Mi agencia, Mercado, Equipos y **Competición** (con un selector interno
   **Calendario | Ligas**). Se **elimina la pestaña Noticias**: el historial
   completo de noticias se muestra desde **Resumen** con un botón
   **"Ver todas"**.
3. **Rivalidades iniciales:** agregar el campo `rivales` en los JSON de equipos
   con unos pocos clásicos, además de las rivalidades que se generen solas.
4. **Guardado de resultados:** se guardan **todos los resultados** de la
   temporada por liga. La tabla de posiciones y el historial directo se derivan
   de ellos.

---

## 3. MODELOS NUEVOS

### 3.1 `modelos/partido.dart`
`ResultadoSerie`: una serie ya jugada.
- `fecha` (int), `etapa` (String: "Liga Split 1", "Playoffs Split 1"...).
- `localId`, `visitanteId` (String).
- `mapasLocal`, `mapasVisitante` (int).
- `ganadorId` (String) — calculado o guardado.
- `toJson()` / `fromJson()`.

### 3.2 `modelos/competicion.dart`
`Competicion`: una liga (un videojuego, una región y una división).
- `juego`, `region`, `division`, `liga` (nombre).
- `equipoIds` (`List<String>`, en orden estable: base del calendario).
- `resultadosSplit1`, `resultadosSplit2` (`List<ResultadoSerie>`).
- `resultadosPlayoffs1`, `resultadosPlayoffs2` (`List<ResultadoSerie>`).
- Getters derivados (sin guardar):
  - `tablaSplit(int split)`: posiciones (jugados, ganados, perdidos,
    mapasG, mapasP, puntos). Victoria = 3, derrota = 0; desempate por
    diferencia de mapas.
  - `campeonSplit(int split)`: ganador de los playoffs.
  - `formaEquipo(String equipoId)`: últimos 5 resultados (V/D) en la temporada.
  - `enfrentamientos(String a, String b)`: historial directo del año.
- `toJson()` / `fromJson()`.

---

## 4. MODELOS MODIFICADOS

### 4.1 `modelos/jugador.dart`
Campos nuevos (todos con valor por defecto, serializados):
- Temporada: `partidasTemporada`, `victoriasTemporada`, `notaTotalTemporada`,
  `eliminacionesTemporada`, `muertesTemporada`, `asistenciasTemporada`,
  `mvpsTemporada`.
- Carrera: `eliminacionesCarrera`, `muertesCarrera`, `asistenciasCarrera`,
  `mvpsCarrera`.
- `ultimasNotas` (`List<double>`, máximo 5, para calcular la forma).

### 4.2 `modelos/equipo.dart`
- Campo `rivales` (`List<String>` de ids de equipos) + `toJson`/`fromJson`.

### 4.3 `modelos/estado_partida.dart`
- Campo `competiciones` (`List<Competicion>`).
- Campo `campeonesTemporada` (lista simple de texto para las noticias).
- Subir `versionFormato` a `3`.

---

## 5. LÓGICA NUEVA

### 5.1 `logica/calendario.dart`
- `etapaDeSemana(int semana)`: devuelve la etapa actual (nombre + detalle).
  - 1–4: Pretemporada · Ventana de fichajes 1.
  - 5–18: `Split 1 · Fecha N` (N = semana − 4).
  - 19–20: Playoffs Split 1.
  - 21–22: Torneo Internacional de Mitad de Temporada (Parte 2C, sin simular).
  - 23–26: Ventana de fichajes 2.
  - 27–40: `Split 2 · Fecha N` (N = semana − 26).
  - 41–42: Playoffs Split 2.
  - 43–46: Mundial (Parte 2C, sin simular).
  - 47–52: Fin de temporada.
- `listaEtapas()`: lista de etapas de la temporada para la pantalla Calendario,
  con el rango de semanas de cada una.

### 5.2 `logica/liga.dart`
- `generarFechas(List<String> equipoIds)`: round-robin para 8 equipos
  (ida y vuelta = 14 fechas, 4 series por fecha). **No se guarda**: se deriva
  del orden de `equipoIds`.
- `simularFecha(Competicion, int split, int fecha)`: juega las 4 series de esa
  fecha (Bo3) y guarda los `ResultadoSerie`.
- `jugarPlayoffs(Competicion, int split)`: semifinales (1º vs 4º, 2º vs 3º) y
  final, al mejor de 5, según la tabla del split.
- `campeonDe(Competicion, int split)`.

### 5.3 `logica/simulador_partidos.dart`
- `poderEquipo(Equipo, List<Jugador>)`: promedio de habilidad de los titulares ×
  (1 + (moralPromedio − 50) / 500) + forma de cada titular
  (`(forma − 3) × 0,5`).
- `simularSerie(...)`: mejor de 3 (liga) o de 5 (playoffs); por cada mapa se
  calcula `probA` según la fórmula del poder y se decide el ganador.
- Tras la serie: nota individual 1,0–10,0, kills/muertes/asistencias según rol,
  KDA, MVP de la serie, y actualización de los contadores (temporada y carrera)
  y de `ultimasNotas` (máx. 5).
- Efectos de moral: +2 al ganar / −2 al perder; **±3** si son rivales.

---

## 6. FÓRMULAS NUEVAS (`logica/formulas.dart`)

Con constantes con nombre al inicio del archivo, como manda `PLAN.md`:
- Poder de equipo y ajuste por forma.
- `probVictoria(poderA, poderB) = 1 / (1 + e^(−(poderA − poderB) / 6))`.
- `notaJugador(habilidad, gano, azar)` = `5 + (habilidad − 60) / 10 + azar(−2..2) + (ganó ? 1 : −0,5)`, limitada a 1..10.
- Eliminaciones por mapa: `azar(5, 25) × (habilidad / 70)`, ×1,3 en roles
  ofensivos (ADC, Mid, Duelista, AWPer, Entry, Carry) y ×0,6 en soportes.
- Muertes y asistencias coherentes con el rol; `KDA = (kills + asistencias) / máx(muertes, 1)`.
- `formaEstrellas(promedioNotas)`: ≥8 → 5★ · 7–7,9 → 4★ · 6–6,9 → 3★ ·
  5–5,9 → 2★ · <5 → 1★. Sin partidos recientes → 3★.
- Puntos de liga: victoria = 3; desempate por diferencia de mapas.

---

## 7. MOTOR (`logica/motor_juego.dart`)

- **Nueva partida:** construir una `Competicion` por cada combinación
  videojuego + región + división, con sus `equipoIds`.
- **`avanzarSemana`:** antes de incrementar la semana, simular la etapa actual:
  - Semanas 5–18 → Split 1, fecha `semana − 4`.
  - Semanas 19–20 → playoffs Split 1 (semifinales y final).
  - Semanas 27–40 → Split 2, fecha `semana − 26`.
  - Semanas 41–42 → playoffs Split 2.
- **Cada 4 semanas:** ajustar el valor de mercado de cada jugador según su nota
  promedio (≥7,5 → +5%; ≤4,5 → −5%).
- **Noticias automáticas:** resultados de mis representados, campeones de cada
  liga y rachas de 4+ victorias seguidas.
- **Nueva temporada:** reiniciar las competiciones y guardar los campeones.
- **Consultas nuevas:** `competicion(juego, region, division)`,
  `proximosPartidosDeMisJugadores`.

---

## 8. INTERFAZ

- `pantalla_principal.dart`: la barra superior muestra la etapa actual
  (`Split 1 · Fecha 6`). La barra inferior pasa a 5 pestañas (se quita
  **Noticias** y se agrega **Competición**).
- `pantalla_competicion.dart`: pantalla contenedora con selector
  **Calendario | Ligas**.
- `pestana_calendario.dart`: lista de etapas de la temporada, marcando la actual.
- `pestana_ligas.dart`: elegir videojuego → región → división; tabla de
  posiciones y resultados de la última fecha; resaltar los equipos donde juegan
  mis representados.
- `pantalla_previa_partido.dart` + `widgets/barra_probabilidad.dart`:
  escudos y nombres, poder y forma (V V D V D), probabilidad de victoria con
  barra de dos colores, historial directo y duelo clave del mismo rol.
- `widgets/estrellas_forma.dart`: muestra la forma en estrellas; se incluye en
  `widgets/tarjeta_jugador.dart` y en `pantalla_detalle_jugador.dart`.
- `pantalla_detalle_jugador.dart`: agrega estadísticas (kills, muertes,
  asistencias, KDA, nota promedio, MVP).
- `pestana_resumen.dart`: agrega **Próximos partidos de mis jugadores** y el
  historial completo de noticias con un botón **"Ver todas"** (sustituye a la
  pestaña Noticias, que se elimina).
- `pantalla_detalle_equipo.dart`: forma del equipo, rival 🔥 y campeón de liga.

---

## 9. DATOS

- Agregar `rivales` iniciales en `assets/datos/equipos_lol.json`,
  `equipos_valorant.json`, `equipos_cs2.json` y `equipos_dota2.json`
  (ej: T1–Gen.G, Fnatic–G2).
- Actualizar `assets/datos/LEEME.txt` explicando el campo `rivales`.
- `datos/cargador_mundo.dart`: leer `rivales` de cada equipo.

---

## 10. ARCHIVOS A CREAR

- `PLAN_2B.md` (este documento)
- `lib/modelos/partido.dart`
- `lib/modelos/competicion.dart`
- `lib/logica/calendario.dart`
- `lib/logica/liga.dart`
- `lib/logica/simulador_partidos.dart`
- `lib/pantallas/pantalla_competicion.dart`
- `lib/pantallas/pestana_calendario.dart`
- `lib/pantallas/pestana_ligas.dart`
- `lib/pantallas/pantalla_previa_partido.dart`
- `lib/widgets/estrellas_forma.dart`
- `lib/widgets/barra_probabilidad.dart`

## 11. ARCHIVOS A MODIFICAR

| Archivo | Cambio |
|---|---|
| `lib/logica/formulas.dart` | Fórmulas de poder, probabilidad, nota, kills y forma. |
| `lib/modelos/jugador.dart` | Estadísticas de temporada y carrera + últimas notas + `toJson`/`fromJson`. |
| `lib/modelos/equipo.dart` | Campo `rivales` + serialización. |
| `lib/modelos/estado_partida.dart` | `competiciones`, campeones y `versionFormato` a 3. |
| `lib/servicios/guardado.dart` | Aviso de versión anterior adaptado a la versión 3. |
| `lib/datos/cargador_mundo.dart` | Leer `rivales` del JSON. |
| `lib/logica/motor_juego.dart` | Competiciones, simulación semanal, noticias, valor por nota, reset de temporada y consultas. |
| `lib/logica/generador_jugadores.dart` | Inicializar los campos nuevos (valores por defecto). |
| `lib/pantallas/pantalla_principal.dart` | Etapa en la barra superior + pestaña Competición. |
| `lib/pantallas/pestana_resumen.dart` | Próximos partidos de mis jugadores. |
| `lib/pantallas/pantalla_detalle_jugador.dart` | Forma en estrellas + estadísticas. |
| `lib/pantallas/pantalla_detalle_equipo.dart` | Forma, rival 🔥 y campeón. |
| `lib/widgets/tarjeta_jugador.dart` | Mostrar la forma en estrellas. |
| `assets/datos/equipos_*.json` | Campo `rivales`. |
| `assets/datos/LEEME.txt` | Explicar `rivales`. |

---

## 12. ORDEN DE TRABAJO

1. Añadir a `lib/logica/formulas.dart` las fórmulas base (poder, probabilidad,
   nota, kills, forma) con sus constantes.
2. Ampliar `lib/modelos/jugador.dart` (estadísticas, últimas notas, forma).
3. Ampliar `lib/modelos/equipo.dart` (campo `rivales`).
4. Crear `lib/modelos/partido.dart` (`ResultadoSerie`).
5. Crear `lib/modelos/competicion.dart` (tabla, forma y head-to-head derivados).
6. Crear `lib/logica/calendario.dart` (etapas de la semana).
7. Crear `lib/logica/liga.dart` (round-robin, fecha, playoffs y campeón).
8. Crear `lib/logica/simulador_partidos.dart`.
9. Modificar `lib/modelos/estado_partida.dart` (competiciones + versión 3).
10. Ajustar `lib/servicios/guardado.dart` a la versión 3.
11. Modificar `lib/datos/cargador_mundo.dart` (leer `rivales`).
12. Modificar `lib/logica/motor_juego.dart` (crear competiciones, simular en
    `avanzarSemana`, noticias, valor por nota, reset de temporada y consultas).
13. Añadir `rivales` a los 4 JSON de equipos y actualizar `LEEME.txt`.
14. Modificar `lib/pantallas/pantalla_principal.dart` (etapa en la barra +
    acceso a Competición).
15. Crear `lib/pantallas/pantalla_competicion.dart`,
    `pestana_calendario.dart` y `pestana_ligas.dart`.
16. Crear `lib/pantallas/pantalla_previa_partido.dart` y
    `lib/widgets/barra_probabilidad.dart`.
17. Crear `lib/widgets/estrellas_forma.dart` y usarla en la tarjeta y el
    detalle; mostrar estadísticas en el detalle del jugador.
18. Modificar `lib/pantallas/pestana_resumen.dart` (próximos partidos).
19. Modificar `lib/pantallas/pantalla_detalle_equipo.dart` (forma, rival y
    campeón).
20. Ejecutar `flutter analyze` y `flutter test`; corregir todo.
21. Ejecutar `flutter run -d linux` y comprobar que abre.
22. Escribir el resumen de prueba en `PROGRESO.md` y explicar cómo probar.

---

## 13. PRUEBAS DE LA PARTE 2B

- [ ] Al avanzar la semana se juegan partidos y se actualizan las tablas.
- [ ] Los jugadores tienen notas y estadísticas.
- [ ] Hay playoffs y campeones de cada liga.
- [ ] Los jugadores muestran su forma en estrellas y estadísticas
      (eliminaciones, KDA).
- [ ] La previsualización muestra probabilidades de victoria antes de cada
      partido.
- [ ] Los clásicos entre rivales aparecen marcados.
- [ ] Las partidas guardadas de la versión 2 avisan de incompatibilidad.
- [ ] `flutter analyze` no muestra errores.
