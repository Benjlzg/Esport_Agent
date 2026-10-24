# PROGRESO — FASE 2

Resumen. El detalle completo de 2A–2D está en `HISTORIAL_FASE2.md`.

## Terminado (2A–2E)

- **2A — Mundo:** regiones, 4 videojuegos, ligas y equipos reales/ficticios desde JSON; 1ª/2ª División, filtros y carga de partida.
- **2B — Ligas y partidos:** calendario, round-robin, playoffs, tablas, estadísticas/KDA, forma, previas con probabilidad y noticias.
- **2C — Torneos y premios:** Torneo de Mitad (21–22) y Mundial (43–46), Palmarés, premios individuales, ceremonia y ascensos/descensos.
- **2D — Mercado vivo:** ventanas de fichajes, fichajes de la IA, ofertas/renovaciones, titulares y suplentes, jóvenes por región.
- **2E — Eventos aleatorios:** eventos semanales de jugador, agencia y mundo; ventana emergente con decisiones y gastos confirmados; lesiones/descansos, inversor y contacto con equipos grandes; frecuencia configurable.

## Decisiones que afectan al trabajo futuro

- **Guardado:** `versionFormato` = **7**; `versionMinimaCompatible` = **3**. Las v3–v6 cargan con los campos nuevos vacíos, reconstruyen el contador de ids y se reguardan como v7; v1/v2 son incompatibles.
- **Ventanas de fichajes:** semanas **1–4, 23–26 y 47–52**; fuera de ellas solo se pueden fichar agentes libres. Las renovaciones se revisan todas las semanas.
- **Botón de depuración:** "Avanzar 10 semanas" solo visible con `kDebugMode`.
- **5 pestañas:** Resumen, Mi agencia, Mercado, Equipos y Competición (Noticias se eliminó; su historial se abre desde Resumen con "Ver todas").
- **Titulares y suplentes:** 5 titulares + hasta 2 suplentes; los suplentes no suman poder. Castigo de −10 de moral por ser suplente todo un split (semanas 18 y 40, umbral 14).
- **Mercado IA:** máximo **2 fichajes por equipo y ventana**; éxito del traspaso 70 %; ofertas por mis jugadores con 2 semanas para responder (Aceptar/Rechazar/Pedir más).
- **Torneos:** el Mundial se adapta al número de clasificados (byes) y termina como muy tarde en la semana 46.
- **Reglas de juego:** victoria = 3 puntos; Bo3 en liga y Bo5 en playoffs; valor de mercado ajustado cada 4 semanas.

## 2E — Eventos aleatorios (terminada)

### Cambios aprobados al plan

- **Avanzar 10 semanas:** los eventos informativos (sin decisión) se resuelven automáticamente y quedan como noticia; solo los eventos con decisión se muestran en la ventana.
- **Alineación con pocos disponibles:** si un equipo tiene menos de 5 jugadores disponibles por lesiones o descansos, `alineacionDe` completará con los disponibles y nunca fallará.

### Hecho (pasos 2 a 23)

- `Jugador`: nuevo `semanasInactivo`, getter `estaInactivo` y serialización tolerante.
- Nuevo `lib/modelos/evento.dart`: `FrecuenciaEventos` y `EventoPendiente` con `toJson`/`fromJson` tolerantes.
- `EstadoPartida`: `eventosPendientes`, `frecuenciaEventos`, `semanasInversor` y `semanasContactoGrande`; `versionFormato` = 6.
- Nuevo `lib/logica/eventos.dart`: constantes de balance, `ContextoEventos`, `DefinicionEvento`, `OpcionEvento`, `limitarCostoEvento`, `multiplicadorFrecuencia`, catálogo completo, generación semanal (máx. 3, 1 de agencia y 1 del mundo) y resolución con límites y noticias.
- Eventos del mundo ya se aplican al generarse y solo dejan noticia; los de jugador y agencia quedan pendientes hasta resolverlos.
- `negociacion.dart`: `calcularRespuesta` acepta `margenExtraAceptacion` y amplía el límite de aceptación.
- `simulador_partidos.dart`: nuevo `alineacionDe` (excluye inactivos, completa con suplentes y nunca falla). `poderEquipo`, `simularSerie` y `simularEnfrentamiento` usan la alineación disponible, así que los lesionados no juegan ni suman poder/estadísticas.
- `motor_juego.dart`: generación de eventos al final de `avanzarSemana`, temporizadores de inactividad/inversor/contacto, getter `eventosPendientes`, `resolverEvento`, `resolverEventosInformativos` y `cambiarFrecuenciaEventos`.
- `motor_juego.dart`: `_comisionNeta` aplica el 10 % del inversor a salarios, traspasos y renovaciones; el contacto grande da +0,10 de margen a equipos con prestigio ≥ 85.
- `motor_juego.dart`: retiradas y efectos de eventos reponen titulares; `_nuevaTemporada` cura la inactividad.
- **Cambio aprobado aplicado:** "Avanzar 10 semanas" resuelve automáticamente los eventos informativos y deja solo las decisiones para la ventana.
- Nuevo `lib/pantallas/pantalla_eventos.dart`: ventana emergente con descripción, costo ya limitado al 30 %, confirmación antes de pagar y opciones A/B.
- `pantalla_principal.dart`: muestra los eventos al avanzar una o diez semanas y al entrar con una partida cargada; luego, la ceremonia de premios.
- `pantalla_ajustes.dart`: selector Baja / Normal / Alta y estado de inversor y contacto grande.
- Fichas, tarjeta de jugador y plantilla del equipo marcan a los inactivos; la previa usa la alineación disponible para el duelo clave.
- `test/eventos_test.dart`: costos, frecuencia, serialización tolerante, compatibilidad v5→v6, alineación, generación y resolución.
- `flutter analyze` sin errores, `flutter test` completo en verde y `flutter build linux --debug` compila; el binario arranca en Linux.

### Siguiente

- Nada pendiente de la Parte 2E. La Fase 3 no forma parte de este plan.

## Fase 2.5 — Pruebas de balance (pasos 2–7, terminada)

### Hecho

- **Semilla reproducible (paso 2):** `MotorJuego({int? semilla})` guarda `semilla` y crea `Random(semilla)`. `AppEsportsAgent({this.motor})` permite inyectar un motor sembrado desde pruebas. Se mantiene el comportamiento normal cuando no se pasa semilla.
- **Métricas (paso 3):** nuevo `lib/logica/metricas.dart` con `MetricasSimulacion`, `ViolacionInvariante`, `ResultadoInvariantes`, `percentil()` y `revisarInvariantes()`. Se cuentan fichajes IA por ventana, ofertas IA, eventos, eventos con decisión, ingresos/gastos y avances semanales. Las métricas no se serializan ni alteran el guardado.
- **Invariantes y límites (paso 5):** `test/limites_test.dart` cubre rangos de habilidad/potencial/moral/reputación, valores/salarios/prestigio/presupuesto negativos, plantillas incompletas y `percentil()`.
- **Corrección de lógica:** al vencer el contrato de un titular, su equipo repone el rol en la misma semana. Sin esto, las plantillas se vaciaban con las temporadas y desde T2 había equipos sin 5 titulares (detectado como violación dura).
- **Simulación larga (pasos 4, 6 y 7):** `test/balance_test.dart` simula **10 temporadas** con semilla fija `20251019`, escribe `INFORME_BALANCE.md` y falla si hay violaciones duras. Usa `test/apoyo/entorno_simulacion.dart` para resolver eventos automáticamente y generar tablas Markdown. Duración aproximada: **61 s**.
- **Resultado final:** 0 violaciones duras; salto máximo de habilidad **2,68** (≤ 3); concentración máxima de títulos **4,0 %**; presupuestos siempre positivos; **6.448** fichajes IA registrados; media global **~118 ms/semana**.
- **Ajustes de balance:** se hicieron **2 de las 3 rondas** permitidas y no quedó nada pendiente. Detalle en `INFORME_BALANCE.md`. Constantes cambiadas: `multiplicadorValorMaximo` 5,0 → 3,0; `probProgresoJoven` 0,30 → 0,22 → 0,30 (revertido); nueva `ajusteHabilidadReemplazo` = -2.
- `flutter analyze` limpio y `flutter test` completo en verde.

### Etiqueta `lento`

- `test/balance_test.dart` lleva `@Tags(['lento'])` y `dart_test.yaml` salta esa etiqueta en la suite normal.
- **Comando efectivo:** `flutter test test/balance_test.dart --tags lento --run-skipped`.
- Desviación conocida: `flutter test --tags lento` por sí solo **no ejecuta** el test porque `package:test` mantiene el `skip`; hay que añadir `--run-skipped`. Se documenta aquí para no repetir el problema.
- `test/robot_test.dart` lleva `@Tags(['lento'])` igual que `balance_test.dart`.

### Notas para fases futuras

- Si cambia el diseño de una pantalla, regenerar las capturas con `flutter test test/golden_test.dart --update-goldens`.

## Fase 2.5 — Pruebas de balance (pasos 8–12, terminada)

### Hecho

- **Robot de 3 temporadas (paso 8):** `test/apoyo/robot_jugador.dart` (`RobotJugador`, `FilaRobot`, `ResultadoRobot`, `ejecutarRobotDePrueba`, `seccionRobotMarkdown`) y `test/robot_test.dart` (`@Tags(['lento'])`). Recluta libres asequibles (habilidad ≤ reputación + 40, potencial ≥ habilidad + 10, coste ≤ 25 % del dinero, máx. 8 representados), vende en ventana pidiendo valor de mercado y acepta ≥ 90 %; acepta traspasos ≥ 92 % y renovaciones sin bajar salario; responde eventos con la opción más barata. Cuenta por temporada decisiones/fichajes/ventas/eventos/ofertas, dinero y reputación, y semanas sin ninguna opción (racha preocupante ≥ 8). Su sección se inserta en `INFORME_BALANCE.md` entre los marcadores `<!-- ROBOT:INICIO -->`/`<!-- ROBOT:FIN -->`.
  - Resultado: **no quiebra**; 8 fichajes y 53 ventas; semanas sin opción 11 y racha máxima 5 (no preocupante); ~17 s.
  - Corrección: la temporada de cada fila se captura al inicio de la vuelta (`temporadaInicio`), no desde el estado mutable (antes daba 2/3/4).
- **Flujo de widgets (paso 9):** `test/widget_flujo_test.dart` con prefs simuladas y motor sembrado. Cubre: nueva partida → crear agente → principal; Mercado → reclutar un libre; detalle → ofrecer a un equipo → oferta aceptada; avanzar 3 semanas resolviendo diálogos; evento inyectado respondido desde la ventana; oferta inyectada aceptada desde `PantallaOfertas`; guardar y continuar en otro motor comprobando semana, temporada, dinero, reputación y representados.
  - Diagnóstico: en pruebas de widget el bundle de assets queda cacheado entre tests y la segunda lectura de `rootBundle` se cuelga; se limpia con `(rootBundle as CachingAssetBundle).clear()` en `setUp`.
- **Capturas golden (paso 10):** `test/golden_test.dart` con fixture determinista (3 reclutados y 8 semanas avanzadas). Carga **Roboto y MaterialIcons reales** desde `bin/cache/artifacts/material_fonts` del SDK (localizada por `FLUTTER_ROOT` o subiendo desde el ejecutable; si no, avisa y usa la fuente de pruebas). Captura a **390×844 lógicos, dpr 2** y guarda en `capturas/`: inicio, crear_agente, resumen, mi_agencia, mercado, equipos, competicion, calendario, ligas, torneos, detalle_jugador, detalle_equipo, negociacion, ofertas, evento, ajustes, palmares y ceremonia (**18 PNG**). Primera ejecución con `--update-goldens`; después, verificación automática.
- **Verificación (paso 11):**
  - `flutter analyze` → limpio.
  - `flutter test` → **58 pasan, 2 saltan** (las `lento`).
  - `flutter test --tags lento --run-skipped test/balance_test.dart test/robot_test.dart` → en verde (~80 s).
  - `flutter build linux --debug` → compila.
  - Compatibilidad: `eventos_test.dart` comprueba que una partida v5 sin campos nuevos carga con valores por defecto y que `versionFormato` = 6 y `versionMinimaCompatible` = 3; el guardado no cambió de formato.

### Comandos

- Suite normal: `flutter test`.
- Balance + robot: `flutter test --tags lento --run-skipped test/balance_test.dart test/robot_test.dart`.
- Regenerar informe de robot: `flutter test test/robot_test.dart --tags lento --run-skipped`.
- Regenerar capturas: `flutter test test/golden_test.dart --update-goldens`.

### Semilla y resultados principales

- Semilla fija de los informes: **20251019**.
- Balance (10 temporadas): 0 violaciones duras; salto máximo de habilidad **2,68** (≤ 3); concentración máxima de títulos **4,0 %**; presupuestos positivos; **6.448** fichajes IA; media global **~118 ms/semana**.
- Constantes ajustadas: `multiplicadorValorMaximo` 5,0 → 3,0; `probProgresoJoven` 0,30 → 0,22 → 0,30 (revertido); nueva `ajusteHabilidadReemplazo` = -2.

### Siguiente

- Nada pendiente de la Fase 2.5. La Fase 3 no forma parte de este plan.

## Fase 2.5 — Correcciones prioritarias A (terminada)

Se implementó solo la sección **A (errores)** de `CORRECCIONES_2_5.md`. La sección B y la Fase 3 no se tocaron.

### A1 — Los ingresos de eventos ya no se muestran como costo

- `OpcionEvento` tiene `ingresoBase` e `ingresoAleatorio`; `EventoPendiente` guarda `ingresoBaseA`/`ingresoBaseB` (por defecto **0**, compatible con guardados viejos).
- `marca_perifericos`, `streamer_estrella` e `inversor_interesado` pagan al agente. En `resolverEvento` el ingreso se aplica **completo**, sin pasar por `limitarCostoEvento` ni pedir confirmación de gasto.
- `pantalla_eventos.dart` muestra los importes como **`+$25.000`** (ingreso) y **`−$10.000`** (costo). El aviso del 30 % solo aparece si alguna opción cuesta dinero.
- Prueba añadida en `test/eventos_test.dart`: aceptar el patrocinio aumenta el dinero.

### A2 — Bloqueo de reventa repetida

- Nuevo campo `Jugador.temporadaUltimoTraspaso` (`null` por defecto) y getter `bloqueadoTraspaso(temporadaActual)`: un jugador traspasado no puede volver a venderse hasta la temporada siguiente.
- Se marca en mis traspasos y en los de la IA.
- Se bloquea en `ofrecer`, `aceptarContraoferta` y `aceptarOferta`, en la selección de candidatos de la IA, en las ofertas de fuga de eventos, en el detalle/negociación y en el robot de pruebas.
- El detalle muestra **"Recién fichado: podrá cambiar de equipo la próxima temporada."** cuando corresponde.
- Pruebas añadidas en `test/mercado_test.dart`.

### A3 — Limpieza y rendimiento con las temporadas

- Nuevo `lib/logica/mantenimiento.dart` (`limpiarDatosAntiguos`), llamado desde `_nuevaTemporada`:
  - Noticias: solo las de las **2 últimas temporadas**.
  - Ofertas de traspaso vencidas: se eliminan.
  - Agentes libres: tope de **300**; se conservan mis representados y los jugadores con premios.
  - Jugadores retirados: ya se quitaban en `_nuevaTemporada`; no quedan listas de resultados históricos que recortar.
- La semana recorre a todos los jugadores **una sola vez** (comisión de salario, contrato, progreso e inactividad), conservando el orden de llamadas al RNG. Antes eran cuatro recorridos.
- `test/balance_test.dart` ahora anota en `INFORME_BALANCE.md` el tamaño de las listas medidas y los **KB del guardado** al final de cada temporada.
- Nuevo `test/mantenimiento_test.dart` para noticias, ofertas vencidas y tope de agentes libres.

### Verificación

- `flutter analyze` → **No issues found!**
- `flutter test` → **68 pasan, 2 saltan** (los `@Tags(['lento'])`).
- Capturas de `capturas/` regeneradas con `flutter test test/golden_test.dart --update-goldens`: los datos del fixture determinista cambian porque A1/A2 alteran la simulación (dinero, reputación, progresión y plantillas de la IA). El resto de pruebas de lógica sigue en verde.
- `versionFormato` sigue en **6**; los campos nuevos tienen valores por defecto y las partidas viejas cargan sin cambios.

### Pendiente (requiere ejecución lenta autorizada)

- Regenerar `INFORME_BALANCE.md` para medir el efecto real de A3 (tamaños de listas, KB del guardado y objetivo de que la semana 10 no tarde más de 1,5× la semana 1). No se ejecutó `balance_test.dart` ni `robot_test.dart`; el informe actual sigue reflejando las cifras anteriores a A3.

## Fase 2.5 — Correcciones prioritarias C (interfaz, terminada)

Se implementó solo la sección **C (interfaz)** de `CORRECCIONES_2_5.md`. La sección B y la Fase 3 no se tocaron.

### Hecho

- **C1 — Selector de Competición:** `SegmentedButton` sin íconos ni marca de selección y con densidad compacta. "Calendario" ya cabe en una sola línea.
- **C2 — Espacio bajo las listas:** nueva constante `margenBotonAvanzarSemana` (**100 px**) en `tema_app.dart`, aplicada al final de las listas de Resumen, Mi agencia, Mercado, Equipos, Calendario, Ligas y Torneos. El botón "Avanzar semana" ya no tapa el último elemento.
- **C3 — Filtros de videojuego:** se cambiaron las filas horizontales por `Wrap` en Mercado, Equipos, Ligas y Torneos. "Dota 2" baja a otra línea completo en vez de cortarse.
- **C4 — Sin emojis:** los trofeos, medallas y el fuego se reemplazaron por íconos de Material (`Icons.emoji_events`, `Icons.military_tech`, `Icons.local_fire_department`) en Resumen, detalle de jugador, detalle de equipo, Palmarés, Torneos y ceremonia de premios.
- **C5 — Ligas al entrar:** se elige automáticamente el primer videojuego (LoL), su primera región y la **1ª División**, así que la pestaña ya no aparece vacía.
- **C6 — Escudos oscuros:** el círculo de iniciales lleva un borde fino gris claro (`#BDBDBD`) para distinguirse del fondo.
- **C7 — Ofrecer un jugador:** el precio pedido se rellena con el valor de mercado y se preselecciona el primer equipo interesado (y no bloqueado). Si no hay interesados, el precio sigue precargado.
- **C8 — Semanas de las ofertas:** el "3" de la captura venía del fixture de `golden_test.dart`; ahora usa **2**. Además, una oferta creada en la semana actual ya no descuenta una semana en el mismo avance, así que el agente dispone realmente de las 2 semanas prometidas. Prueba nueva en `test/mercado_test.dart`.

### Revisión y pruebas de interfaz (2026-10-21)

- Nuevo `test/interfaz_test.dart` con **7 pruebas** que cubren C1–C7:
  - C1: a **320 px** de ancho, "Calendario", "Ligas" y "Torneos" ocupan una sola línea en el `SegmentedButton`.
  - C2: Resumen, Mi agencia, Mercado, Equipos, Calendario y Ligas reservan exactamente `margenBotonAvanzarSemana` (**100 px**) al final de su lista.
  - C3: Mercado, Equipos y Ligas usan `Wrap` y "Dota 2" aparece completo a 320 px.
  - C4: recorre todo `lib/` y falla si aparece un emoji; se cambió un `★` que quedaba en un comentario de `formulas.dart`.
  - C5: Ligas abre con la 1ª División seleccionada y sin el mensaje de "elige un videojuego...".
  - C6: el círculo de iniciales de un equipo negro tiene borde `#BDBDBD`.
  - C7: la negociación abre con el valor de mercado en el precio y el primer equipo interesado seleccionado, también a 320 px.
- **C7 más robusto:** el desplegable de equipo usa `isExpanded: true` y recorta con puntos suspensivos los nombres largos, para que no se desborde en pantallas estrechas.
- Se extrajo la carga de fuentes reales del SDK a `test/apoyo/fuentes.dart`, compartida con `golden_test.dart`. Sin Roboto/MaterialIcons, la fuente de pruebas hace que los textos parezcan más anchos y las pruebas de 320 px darían falsos positivos.

### Verificación

- `flutter analyze` → **No issues found!**
- `flutter test` → **69 pasan, 14 fallan y 2 saltan** (las `lento`). Los 14 fallos son únicamente las comparaciones de `test/golden_test.dart`, porque las imágenes de `capturas/` siguen mostrando la interfaz anterior. **No se regeneraron** por instrucción expresa.
- Las **69 pruebas restantes** pasan, incluidas las 7 nuevas de `test/interfaz_test.dart` y las de ofertas. No se ejecutaron `balance_test.dart` ni `robot_test.dart`.
- `versionFormato` sigue en **6** y la sección C no añade campos al guardado.

### Pendiente

- Capturas regeneradas en las correcciones de detalles de interfaz (2026-10-21).
- La sección **D (pruebas lentas e informe)** sigue pendiente.
- Mantener el pendiente de la Fase 4: el presupuesto de los equipos se reinicia cada temporada (B4).

## Fase 2.5 — Correcciones de balance B (terminada)

Se implementó solo la sección **B (balance)** de `CORRECCIONES_2_5.md`.

### B1 — Robot con la economía real

- `test/apoyo/robot_jugador.dart`: el robot ahora empieza con **$50.000** y **reputación 10** (`robotDineroInicial`, `robotReputacionInicial`), igual que un jugador nuevo. Se **reemplazó** la versión del robot rico; no se conservó porque no aportaba otra métrica.
- `crearPartidaSembrada` acepta `dinero` y `reputacion`, así que el robot y la partida observadora comparten el mismo entorno.
- Nuevas métricas del robot:
  - dinero mínimo y la **temporada/semana** en que se alcanzó;
  - ingresos acumulados por fuente: comisiones de salario, traspasos, renovaciones y eventos;
  - **fuente principal de ingresos**;
  - criterio B1 (sin quiebra y ≤ **$5.000.000** al final de la T3), que se anota en el informe.
- `seccionRobotMarkdown` escribe en `INFORME_BALANCE.md` el dinero por temporada, la quiebra, la semana con menos dinero, la fuente principal y el desglose de ingresos.

### B2 — Eventos repetidos

- Nuevo campo `EstadoPartida.ultimaSemanaEvento` (`{}` por defecto, compatible con partidas viejas): guarda la última semana absoluta de cada evento.
- Constantes nuevas en `eventos.dart`: **26 semanas** para el mismo evento del mismo jugador y **12 semanas** para el mismo evento de agencia. La comprobación se hace en `_elegirDefinicion` con `eventoEnEspera`.
- Al generar un evento se anota su semana; los eventos del mundo no usan espera.
- `marca_perifericos` baja de peso **10 → 6**.
- `mantenimiento.dart` elimina los registros de espera que ya no bloquean nada.
- Pruebas nuevas en `test/eventos_test.dart` y `test/mantenimiento_test.dart` (peso, 26/12 semanas, espera por jugador, registro al generar y limpieza).

### B3 — Dominio por liga

- Se eliminó la métrica **"% del total de títulos"** de `balance_test.dart`.
- Nuevo `dominioPorLiga` en `test/apoyo/entorno_simulacion.dart`: para cada liga de **1ª División** cuenta en cuántas **temporadas distintas** el mismo equipo ganó al menos un split y cuántos títulos de split sumó.
- `INFORME_BALANCE.md` incluirá la tabla de las **5 ligas con un campeón más repetido** (temporadas ganadas de 10 y títulos de split) y el criterio orientativo **≤ 6 de 10**.
- Si alguna liga supera el criterio, el informe lo anota y propone un ajuste (reducir el determinismo de las series o añadir desgaste a los campeones) **sin aplicarlo**.

### B4 — Pendiente de la Fase 4 (economía)

- **No se cambió ahora:** el presupuesto de los equipos se reinicia en cada `_nuevaTemporada` (`equipo.presupuesto = prestigio * 20000`), así que los premios y las ventas no se acumulan.
- Queda anotado como pendiente de la **Fase 4 (economía)**.

### Verificación

- `flutter analyze` → **No issues found!**
- `flutter build linux --debug` → compila.
- `flutter test` → **75 pasan, 14 fallan y 2 saltan**. Los 14 fallos son solo las comparaciones de `test/golden_test.dart`: las capturas siguen mostrando la interfaz anterior desde la sección C y no se regeneraron (D). De las 18 capturas, 4 coinciden; las **71 pruebas de lógica y widgets pasan**, incluidas las nuevas de B2, `test/dominio_liga_test.dart` (B3) y `test/robot_metricas_test.dart` (B1).
- Prueba nueva de B2: el tiempo de espera de 26 semanas también se comprueba cruzando el cambio de temporada.
- Prueba nueva de B1: si el robot quiebra, el saldo de esa semana se registra como el mínimo de la partida.
- No se ejecutaron `test/balance_test.dart` ni `test/robot_test.dart` (lentos), por indicación del usuario.
- `versionFormato` sigue en **6**; `ultimaSemanaEvento` tiene valor por defecto y las partidas viejas cargan sin cambios.

### Pendiente

- Ejecutar las pruebas lentas y regenerar `INFORME_BALANCE.md` para comprobar el robot con $50.000, el dominio por liga y el efecto de B2.
- Si el robot quiebra o termina la T3 con más de $5.000.000, ajustar constantes (máximo 3 rondas, anotando antes y después).
- Capturas regeneradas en las correcciones de detalles de interfaz (2026-10-21).
- **B4 — pendiente de la Fase 4 (economía):** el presupuesto de los equipos se reinicia en cada `_nuevaTemporada` (`equipo.presupuesto = prestigio * 20000`), así que los premios y las ventas no se acumulan. **No se cambia en la Fase 2.5.**

## Fase 2.5 — Correcciones de detalles de interfaz (terminada)

Se corrigieron los detalles encontrados en las capturas nuevas sin tocar la Fase 3.

### Hecho

- **Patrocinio (A1):** el evento falso de `test/golden_test.dart` tenía `costoBaseA: 1000`; la lógica real de `marca_perifericos` ya pagaba al agente. El fixture ahora usa `ingresoBaseA: 25000`, así que el botón muestra **"+$25.000"** y no aparece el aviso del 30 %. Se añadieron dos pruebas de interfaz: una comprueba el ingreso y el cobro real; otra comprueba que el aviso del 30 % solo aparece cuando hay una opción con costo.
- **Temporadas:** la barra superior muestra **"Temp. 1 · Sem 9"** y la ceremonia **"Ceremonia · Temp. 1"**. También se cambió el detalle de premios del jugador y los títulos del equipo para no confundir "T1" con el equipo T1.
- **Textos internos:** se quitaron las referencias "(Parte 2C)" de las descripciones del Calendario.
- **Nicks únicos:** nuevo registro de nicks usados al cargar el mundo y al generar jugadores (libres, jóvenes y reemplazos). Si un nick se repite, se conserva el primero y los siguientes reciben un número ("Drift", "Drift2"...). `_reconstruirIndices` también corrige partidas viejas con duplicados. Pruebas nuevas en `test/nicks_test.dart`.
- **Filtros de Ligas:** las regiones (y las divisiones) usan `Wrap`, igual que los videojuegos, y bajan a otra línea en pantallas estrechas.
- **Jugadores sin partidos:** el detalle muestra **"—"** en nota promedio y KDA (también en el KDA de carrera) en vez de "0.00".
- **Golden de temporada:** `test/golden_test.dart` avanza la partida hasta la **semana 47**, después del Mundial. Torneos, Palmarés y Ceremonia muestran campeones, títulos y premios reales; la ceremonia reutiliza esa misma partida.

### Verificación

- `flutter analyze` → **No issues found!**
- `flutter test` → **97 pasan, 2 saltan** (las pruebas `@Tags(['lento'])`). Incluye las 4 pruebas nuevas de nicks y las 4 nuevas de interfaz.
- Capturas de `capturas/` regeneradas con `flutter test test/golden_test.dart --update-goldens`.
- No se ejecutaron `test/balance_test.dart` ni `test/robot_test.dart` (pruebas lentas), por indicación del usuario.
- `versionFormato` sigue en **6**; esta corrección no añade campos al guardado.

## Fase 2.5 — Balance real y progresión (terminada, 2026-10-21)

### Diagnóstico del informe que no cambiaba

- Las pruebas lentas **sí se ejecutan** con `flutter test --tags lento --run-skipped` y escriben en `INFORME_BALANCE.md` en la raíz del proyecto. No están saltadas ni escriben en otra ruta.
- La causa real: el commit «Correcciones 2.5: balance» no incluyó el informe regenerado. El archivo versionado seguía mostrando el robot con $1.000.000.000, sin dominio por liga ni tamaño del guardado. Además el informe no tenía fecha/hora, así que dos ejecuciones con la misma semilla parecían idénticas.
- **Corrección:** el informe ahora empieza con `- Generado: **AAAA-MM-DD HH:MM:SS**`, y `balance_test.dart` comprueba después de escribir que el archivo existe, tiene la fecha y la sección de progresión. El informe final se versiona en el commit.

### Sección B revisada (completa)

- **B1:** robot con **$50.000** y reputación **10**; anota dinero por temporada, quiebra, semana con menos dinero, fuente principal e ingresos por fuente.
- **B2:** espera de **26 semanas** para el mismo evento del mismo jugador y **12 semanas** para eventos de agencia; `marca_perifericos` con peso **6**.
- **B3:** tabla de dominio por liga de 1ª División (5 ligas con campeón más repetido) y criterio ≤ 6 de 10.
- **B4:** presupuesto que se reinicia cada temporada queda anotado como pendiente de la Fase 4.
- **A3:** noticias de 2 temporadas, resultados de la temporada actual, agentes libres limitados a 300, ofertas vencidas y eventos resueltos eliminados; el informe incluye el tamaño del guardado en KB.

### Progresión juvenil

- Nuevo `lib/logica/progresion.dart`: probabilidad semanal según edad (16–19 → 10 %, 20–21 → 9 %, 22–23 → 5 %), subida de 1–2 puntos hasta los 21 y de 1 punto después.
- Sin equipo la probabilidad se multiplica por **0,5**; un suplente por **0,85**; moral alta da un bonus de ×1,10.
- `test/progresion_test.dart` cubre probabilidades, la mitad sin equipo, suplentes, moral, media de 4–8 puntos y el tope del potencial.
- **3 rondas de ajuste** documentadas en el informe:
  1. Tabla nueva → media 4,2, pero salto T1 → T2 de 3,17 (límite 3).
  2. Subir 16–19 → media 4,4, salto 3,19 y robot con racha de 8 (preocupante); revertida.
  3. Volver a la tabla anterior y bajar `ajusteHabilidadReemplazo` de **-2 a -3** → media 4,2, salto **2,69** y robot con racha máxima **5**.

### Resultado final del informe

- Generado el **2026-10-21 23:04:28** (hora local), semilla **20251019**.
- 0 violaciones duras; salto máximo de habilidad **2,69** (≤ 3); progresión 16–21 con equipo **4,2** puntos/temporada (4–8).
- Robot: no quiebra, termina la T3 con **$627.916** (≤ $5.000.000), principal ingreso **eventos**, racha máxima **5** (no preocupante).
- Tiempo T10 / T1: **1,33×** (meta ≤ 1,5×); guardado final **3.592,7 KB**; **6.914** fichajes IA.
- **Dominio por liga:** sigue en **10 de 10** para varios equipos; **no cumple** el criterio ≤ 6. Se deja anotado para la Fase 4 porque B3 pide medirlo/proponerlo sin aplicarlo y B4 (economía) sigue pendiente.
- Capturas de `capturas/` regeneradas con `flutter test test/golden_test.dart --update-goldens` porque el fixture cambia con la nueva progresión.

### Verificación

- `flutter analyze` → **No issues found!**
- `flutter test` → **105 pasan, 2 saltan** (las `@Tags(['lento'])`).
- `flutter test --tags lento --run-skipped` → **2 pasan** (`balance_test.dart` y `robot_test.dart`).
- `versionFormato` sigue en **6**; no hay campos nuevos en el guardado.

### Pendiente

- **B4 — Fase 4 (economía):** el presupuesto de los equipos se reinicia cada temporada; los premios y las ventas no se acumulan.

## Fase 2.5 — Balance: dominio, ingresos y reputación (terminada, 2026-10-21)

Se corrigieron los 3 problemas de balance con **3 rondas** de ajuste, todas anotadas en `INFORME_BALANCE.md`.

### 1. Dominio por liga

- **Series más abiertas:** `factorProbabilidad` subió de **6,0 a 18,0**. La ventaja por poder sigue existiendo, pero una serie ya no queda casi decidida de antemano.
- **Equipos ficticios de 1ª División:** antes se generaban con prestigio **35–54** (nivel de 2ª) y ahora con **70–80**. Las regiones con pocos equipos reales dejaron de tener un campeón fijo.
- **Anti-dinastía:** al abrir la primera ventana, los equipos con **3+ títulos de split en 5 temporadas** pierden entre **3 y 5 figuras**. Solo pueden comprarlas equipos que no sean dinastías, con una cláusula de salida del **40 %** del valor. Así las figuras no circulan solo entre los mismos equipos fuertes.
- **Desgaste de campeones:** la plantilla campeona empieza la temporada siguiente con **−10 de moral**. Además, cada título reciente por encima de 2 resta **4 % de poder** (máximo 20 %); el equipo recupera el 100 % cuando deja de ganar.
- **Mercado IA:** el orden de los equipos se baraja cada ventana para que los más fuertes no elijan siempre los mejores agentes libres.
- **Red de seguridad:** al cerrar cada ventana se comprueban los 5 roles de todos los equipos y se repone cualquier titular que falte.

**Resultado:** máximo **6 de 10** temporadas con el mismo campeón; **0 ligas** por encima del criterio (antes 17).

### 2. Ingresos

- `gananciaStreamer` pasó de 5.000–20.000 a **2.000–6.000**.
- `gananciaMarca` pasó de 10.000–50.000 a **4.000–15.000**.
- `gananciaInversor` pasó de 25.000–100.000 a **8.000–30.000**.

**Resultado del robot:** traspasos **$229.920** vs eventos **$135.730**. La fuente principal vuelve a ser **Traspasos**.

### 3. Reputación

- **Diagnóstico:** la reputación bajaba por eventos negativos (`polemica_redes` y `rumor_negativo`, −2 cada uno), que en la T3 superaban las 8 ventas del robot, que solo daban +1 cada una.
- Cada traspaso da **+2** (normal) o **+3** (equipo de élite, prestigio ≥ 85). A partir de 30 el traspaso suma **+1**, y a partir de 40 los traspasos ya no suman: la reputación sigue subiendo solo con eventos, premios o títulos. Es un rendimiento decreciente para no pasarse del objetivo.
- **Resultado del robot:** **10 → 24 → 29 → 37** al final de la T3 (meta 30–45). Crece en las tres temporadas y nunca baja.

### Cambios técnicos y verificación

- **Guardado:** nuevo campo `Equipo.factorPoder` (por defecto **1,0**). Las partidas viejas cargan sin cambios; `versionFormato` sigue en **6**.
- **Pruebas nuevas:** `test/balance_reglas_test.dart` cubre el divisor de probabilidad, el prestigio de los ficticios, los topes de ingresos, la reputación por traspaso y la serialización de `factorPoder`.
- **Informe:** `INFORME_BALANCE.md` regenerado el **2026-10-21 23:53:28**, semilla **20251019**. Incluye la tabla de las 3 rondas y los resultados finales.
- `flutter test --tags lento --run-skipped` → **2 pasan** (`balance_test.dart` y `robot_test.dart`).
- `flutter test` → **112 pasan, 2 saltan** (las lentas).
- `flutter analyze` → **No issues found!**
- Capturas de `capturas/` regeneradas porque la simulación del fixture cambió.
- Sin violaciones duras; salto máximo de habilidad **2,86**; progresión juvenil **4,4**; tiempo T10/T1 **1,22×**; guardado final **3.591,7 KB**.

## Auditoría — C1 y C2 (terminada, 2026-10-22)

Se corrigieron solo los dos problemas críticos de integridad de la partida de `AUDITORIA.md`. C3–C6 y los problemas importantes/menores no se tocaron.

### C1 — IDs de jugador duplicados al cargar

- `EstadoPartida` tiene un campo nuevo `siguienteIdJugador` (por defecto **0**) que se guarda en el JSON. `versionFormato` sube a **7**; `versionMinimaCompatible` sigue en **3**.
- `MotorJuego._nuevoId()` ya no usa un contador solo en memoria: lee y avanza `estado.siguienteIdJugador`, así el valor viaja con la partida.
- `_reconstruirIndices()` recupera el contador al cargar a partir del mayor id `p####` encontrado (y conserva el guardado si ya era mayor). Esto repara partidas v3–v6 sin el campo y evita que el siguiente jugador repita `p0000`.
- Prueba nueva `test/guardado_test.dart`: 50 jugadores `p0000`–`p0049` → guardar → cargar → generar un reemplazo; todos los ids son únicos y el siguiente es `p0050`. También carga versiones 3, 4, 5 y 6 y comprueba que reconstruyen el contador.

### C2 — Excepción al borrar la partida

- `MotorJuego.borrar()` ya no llama a `notifyListeners()` después de dejar `estado = null`; las pantallas que borran navegan al inicio justo después.
- `finDelJuego` es seguro (`estado?.finDelJuego ?? false`) y `PantallaAjustes`/`PantallaPrincipal` muestran `PantallaInicio` si no hay partida, en vez de leer getters que necesitan el estado.
- Prueba nueva `test/borrado_test.dart`: monta Ajustes y borra con las dos confirmaciones; monta la pantalla de bancarrota y pulsa "Empezar de nuevo". En ambos casos no hay excepción y se llega al inicio.

### Verificación

- `flutter analyze` → **No issues found!**
- `flutter test` → **116 pasan, 2 saltan** (las pruebas `@Tags(['lento'])`).
- `test/eventos_test.dart` actualizado para esperar `versionFormato` = **7**; la compatibilidad desde v3 se mantiene.

## Auditoría — C3 a C6 (terminada, 2026-10-22)

Se corrigieron solo los cuatro problemas críticos restantes de `AUDITORIA.md` (C3–C6) y el mecanismo anti-dinastía ahora genera una oferta cuando quiere fichar a un jugador representado. Los problemas importantes (I1–I15) y menores siguen pendientes.

### C3 — Fichajes juveniles y anti-dinastía

- Nuevo `ficharJovenesDeSegunda` en `lib/logica/mercado.dart` (el motor lo llama al empezar la temporada):
  - **Nunca ficha a un representado**; si es mío, se queda libre o recibe una oferta.
  - Solo ficha jugadores de **21 años o menos**.
  - Respeta el **máximo de 2 suplentes** por equipo.
  - Marca `temporadaUltimoTraspaso` para que no se revenda en la misma temporada.
- **Anti-dinastía con oferta:** `_fichajesDeCampeones` ya no ignora a los representados. Si la figura elegida es mía, crea una `Oferta` con el importe de la **cláusula de salida (40 %)** y el jugador **sigue en su club** hasta que yo decida. No se duplican ofertas del mismo comprador por el mismo jugador.
- El comprador no paga nada hasta que se acepta la oferta.

### C4 — Validación de ofertas entrantes

- `Oferta` tiene tres campos nuevos con valores por defecto para partidas viejas: `equipoOrigenId`, `mejorasRealizadas` y `montoMaximo`.
- Nuevo `_motivoTraspasoInvalido` centraliza las comprobaciones al aceptar un traspaso o una contraoferta:
  - la oferta sigue existiendo en `estado.ofertas`;
  - el jugador sigue representado;
  - sigue en el **club de origen** de la oferta;
  - el comprador es de **otro club** y del **mismo videojuego**;
  - el mercado está abierto (salvo agentes libres);
  - el jugador no está bloqueado por un traspaso reciente;
  - el comprador tiene `presupuesto >= monto`.
- Si la oferta no es válida se elimina y no se paga comisión. Las renovaciones también comprueban representación, club y contrato vigente, así que un **doble toque cobra una sola comisión**.
- Las ofertas de `fuga_informacion` solo se generan con rivales que pueden pagar.
- Se sustituyó `max(0, presupuesto - precio)` por resta directa: la validación previa garantiza que no hay sobregiro.

### C5 — “Pedir más” con tope

- Máximo **2 mejoras** por oferta (`maxMejorasOferta`).
- El importe se acota a `min(valorMercado × 1,40, presupuesto del comprador)` con `topeMontoOferta`.
- **No se reinicia `semanasRestantes`** al pedir más: la oferta conserva su plazo real.
- Una oferta obsoleta (jugador cambiado de club, ya no representado o bloqueado) se elimina y no se puede mejorar.

### C6 — No vender al propio club

- `ofrecer` y `aceptarContraoferta` rechazan al club actual del jugador.
- `PantallaNegociacion` excluye el club actual del desplegable y tampoco lo preselecciona.
- El valor inicial del desplegable se busca en la lista filtrada para evitar excepciones si el club cambia.

### Pruebas nuevas

- `test/anti_dinastia_test.dart` (**6 pruebas**): oferta de la dinastía por la cláusula sin cambiar al representado, no duplicar ofertas, y fichajes juveniles con representado, edad, suplentes y marcado de traspaso.
- `test/ofertas_dinero_test.dart` (**11 pruebas**): oferta al propio club y contraoferta al propio club, desplegable sin el club actual, presupuesto 0, oferta obsoleta por cambio de club, jugador no representado, doble aceptación de renovación, serialización tolerante, tope de mejoras, tope por presupuesto y plazo sin reinicio.

### Verificación

- `flutter analyze` → **No issues found!**
- `flutter test` → **133 pasan, 2 saltan** (las pruebas `@Tags(['lento'])`). Las 17 pruebas nuevas pasan.
- No se ejecutaron `test/balance_test.dart` ni `test/robot_test.dart` (lentos), por la misma indicación de las correcciones anteriores.
- `versionFormato` sigue en **7**; los campos nuevos de `Oferta` tienen valores por defecto y las partidas viejas cargan sin cambios.

### Pendiente (de aquella corrección)

- **I2 e I7:** quedaron pendientes entonces; se resolvieron en la sección «Auditoría — economía e idempotencia» de abajo.
- Regenerar `INFORME_BALANCE.md` y ejecutar las pruebas lentas para medir el efecto de C3–C6 en el robot y en el mercado.

## Auditoría — economía e idempotencia (I1–I15, terminada, 2026-10-22)

Se corrigieron los problemas importantes **I2, I4, I5, I6, I7, I8, I12 e I15**, y se aplicó la alternativa pedida para **I1**. Los problemas menores y el resto de la auditoría siguen pendientes.

### I1 — Periodo mínimo de representación (sin tocar la comisión)

- **La comisión de traspaso sigue siendo el 10 %** (`comisionTransferencia`).
- Nuevo campo `Jugador.semanasRepresentado`: empieza en **0**, sube una semana por cada `avanzarSemana` mientras el jugador sea tuyo y se reinicia a 0 al dejarlo o volver a reclutarlo.
- Nueva constante `semanasMinimasRepresentacion = 8` en `formulas.dart`.
- `MotorJuego.ofrecer` rechaza la oferta antes de las 8 semanas y no consume rondas de negociación.
- La ficha del jugador muestra **"Tiempo como representado: X semanas"**, el aviso de cuántas faltan y el botón "Ofrecer a un equipo" deshabilitado. La pantalla de negociación también bloquea el envío.
- El robot de pruebas respeta el periodo mínimo antes de vender.

### I2 — El club vendedor recibe el dinero

- `_cerrarTrato` acredita al club de origen **precio − comisión bruta del 10 %**. La parte del inversor sale de mi comisión, no del vendedor.
- Los traspasos automáticos de la IA y las cláusulas anti-dinastía acreditan al vendedor; en esos casos no hay agente mío y recibe el precio completo.
- Prueba de conservación: comprador −100.000, vendedor +90.000 y agente +10.000 (suma 0).

### I4 — Doble aceptación y doble resolución

- `aceptarOferta`, `rechazarOferta` y `pedirMasOferta` ya comprobaban que la oferta siguiera en la lista; se mantiene.
- `resolverEvento` comprueba la lista **en el motor y en `eventos.dart`**: si el evento ya no está pendiente devuelve "ya no está disponible" y no aplica dinero, moral ni habilidad por segunda vez.

### I5 — Doble toque en "Avanzar semana" y guardados en orden

- Nuevo `MotorJuego.avanzando`: si ya hay un avance en curso, la segunda llamada se ignora.
- El FAB "Avanzar semana" y el atajo de 10 semanas se deshabilitan mientras se procesa.
- `_guardarYNotificar` usa una **cola de guardado**: las escrituras se hacen una detrás de otra y la UI se avisa antes de esperar al disco.
- Prueba de widget con dos pulsaciones seguidas: la semana avanza exactamente 1.

### I6 — Ofertas obsoletas

- Nuevo `_invalidarOfertasObsoletas`: elimina ofertas si el jugador ya no existe, dejó de ser mío, cambió de club o de videojuego, el comprador no puede pagar, el contrato de renovación no está vigente o el jugador está bloqueado por un traspaso reciente.
- Se ejecuta al avanzar la semana, al dejar de representar, al cerrar un traspaso y al resolver un evento (libertad, cambio de juego o pérdida de representación).
- Pruebas: dejar de representar, traspaso con dos ofertas, cambio de videojuego por evento y presupuesto insuficiente.

### I7 — Salario de la oferta aplicado

- `_cerrarTrato` acepta `salarioAnual` y lo asigna al jugador. `aceptarOferta` pasa el salario de la oferta; las ofertas directas usan el salario de mercado.
- Los fichajes de la IA y las cláusulas anti-dinastía también actualizan el salario.
- Prueba: aceptar una oferta con salario 123.456 deja exactamente ese salario en la ficha.

### I8 — Reemplazos del anti-dinastía en el índice

- `_fichajesDeCampeones` recibe `indiceJugadores` y `porJuegoRol`, y registra al reemplazo generado en ambos.
- Prueba: tras el anti-dinastía, todos los jugadores del estado (incluido el reemplazo) se encuentran con `jugadorPorId`.

### I12 — Confirmación al vender

- `PantallaOfertas` pide confirmación antes de aceptar un traspaso, con jugador, club y precio.
- `PantallaNegociacion` pide confirmación antes de aceptar una contraoferta.
- Prueba de widget: cancelar no cambia al jugador ni elimina la oferta; confirmar sí cierra el traspaso.

### I15 — Límite de eventos pendientes

- Nueva constante `maxEventosPendientes = 8` y función `limitarEventosPendientes`.
- Al generar eventos, si la lista supera 8, expiran los más antiguos y queda una noticia.
- `resolverEvento` es idempotente en motor y lógica.
- Pruebas: doble resolución con un ingreso de 25.000 (solo cobra una vez), recorte de 10 a 8 y avance semanal con pendientes acumulados.

### Guardado y compatibilidad

- `versionFormato` sube a **8** por `semanasRepresentado`; `versionMinimaCompatible` sigue en **3**.
- Las partidas v3–v7 cargan con el campo nuevo a 0 y el contador de ids reconstruido.
- `test/guardado_test.dart` actualizado para cargar también v7 y comprobar la versión 8.

### Verificación

- `flutter analyze` → **No issues found!**
- `flutter test` → **149 pasan, 2 saltan** (las pruebas `@Tags(['lento'])`).
- Capturas de `capturas/` regeneradas con `flutter test test/golden_test.dart --update-goldens` porque cambian la simulación y la ficha del jugador.
- No se ejecutaron `test/balance_test.dart` ni `test/robot_test.dart` (lentos); `INFORME_BALANCE.md` no se regeneró.

### Pendiente

- Regenerar `INFORME_BALANCE.md` y ejecutar las pruebas lentas para medir el efecto de I1–I15 en el robot, el mercado y los presupuestos.
- **B4 — Fase 4:** el presupuesto de los equipos se sigue reiniciando cada temporada; esta corrección solo acredita al vendedor durante la temporada.
- El resto de problemas menores de `AUDITORIA.md` (M1–M19) sigue pendiente.

## Auditoría — guardado, rendimiento y motor (I3, I9, I10, I11; terminada, 2026-10-22)

Se corrigieron los cuatro problemas indicados de `AUDITORIA.md`. La API pública que usan las pantallas no cambió y `versionFormato` sigue en **8**.

### I3 — Guardado en archivo propio, atómico y con copia `.bak`

- Nuevo `lib/servicios/repositorio_partida.dart`:
  - La partida se guarda en `partida_esports_agent.json` dentro de la carpeta privada de la app que devuelve **path_provider** (`getApplicationSupportDirectory`).
  - **Escritura atómica:** primero se escribe `partida_esports_agent.json.tmp` con `flush: true` y después se renombra sobre el principal (mismo directorio).
  - Antes de reemplazar el principal se copia el guardado anterior a `partida_esports_agent.json.bak`.
  - Si el principal está dañado, se carga el `.bak` y se repara el principal.
  - `borrarPartida()` elimina principal, respaldo, temporales y la clave antigua.
- **Migración automática:** si no hay archivo y existe la clave `partida_esports_agent` en `shared_preferences`, se lee, se valida y se guarda en el archivo nuevo; solo entonces se borra la clave antigua. Las partidas v3–v8 siguen cargando.
- `lib/servicios/guardado.dart` conserva las funciones históricas `guardarPartida`, `cargarPartida`, `existePartida` y `borrarPartida`, que ahora delegan en el repositorio.
- **Paquete añadido:** `path_provider` (el usuario lo pidió expresamente). Es el único paquete nuevo.
- En `flutter test` sin plugins, el repositorio usa un almacén en memoria para que las pruebas de widgets no dependan de E/S real. Las pruebas de archivo pasan una carpeta temporal explícita.
- `resolverEventosInformativos` guarda **una sola vez al final**, no una vez por evento (mejora del punto de rendimiento de I3).
- Pruebas nuevas en `test/guardado_test.dart`: respaldo `.bak`, ausencia de `.tmp`, recuperación desde el respaldo y migración desde `shared_preferences`.

### I9 — Índice de plantillas y titulares en el mercado

- Nuevo `lib/logica/indices_mundo.dart` (`IndicesMundo`): jugadores/equipos por id, plantilla por equipo, titular por equipo+rol y representados por equipo.
- `procesarMercadoIA` construye una sola vez el mapa `equipo → (rol → titular)` y lo actualiza con cada traspaso, suplente liberado y reemplazo.
- `_garantizarTitulares` ya no hace `estado.jugadores.any(...)` por cada equipo y rol; consulta el índice.
- `titularMasDebil` acepta el índice del equipo (se conserva la firma antigua para las pruebas y usos externos).
- El índice local de `porEquipo` también se actualiza al mover jugadores, algo que antes quedaba desfasado dentro de la misma ventana.
- Nueva prueba `test/rendimiento_test.dart`: 320 equipos y 2.800 jugadores, ventana de mercado por debajo de **3 s** (en la práctica, milisegundos), más una prueba de actualización del índice tras cambiar equipo y rol.

### I10 — Solo se reconstruye la pestaña visible

- `MotorJuego.revision` sube con cada `notifyListeners`.
- `PantallaPrincipal` conserva las instancias de las pestañas y solo genera de nuevo la activa; las demás no se reconstruyen en cada notificación. Su estado (filtros, scroll) se conserva porque siguen en el `IndexedStack`.
- `PestanaMercado` cachea la lista filtrada/ordenada y la invalida solo si cambia `revision` o algún filtro.
- `proximosPartidosDeMisJugadores` usa `IndicesMundo.representadosPorEquipo`, así que ya no recorre los ~2.800 jugadores por cada competición.

### I11 — Servicios extraídos de `motor_juego.dart`

`MotorJuego` sigue siendo la fachada `ChangeNotifier` y mantiene los mismos métodos públicos; las pantallas no se tocaron. La lógica se repartió en:

- `lib/logica/indices_mundo.dart` — índices derivados del estado.
- `lib/servicios/repositorio_partida.dart` — persistencia.
- `lib/logica/servicios/mercado_service.dart` — reclutar, ofrecer, contraofertas, ofertas, renovaciones, mercado IA y anti-dinastía.
- `lib/logica/servicios/temporada_service.dart` — avance semanal, contratos, progresión, suplentes, nueva temporada, ascensos, retiradas y jóvenes.
- `lib/logica/servicios/competicion_service.dart` — ligas, playoffs, torneos, palmarés y premios.
- `lib/logica/servicios/eventos_service.dart` — generación, resolución, eventos informativos y frecuencia.
- `lib/logica/eventos_catalogo.dart` — catálogo de eventos separado del motor; `eventos.dart` lo reexporta para no romper importaciones.

Tamaños resultantes: `motor_juego.dart` pasó de **1.910 a 626 líneas**; `eventos.dart` de **1.402 a 304**, con el catálogo en un archivo aparte de 1.114 líneas.

### Verificación

- `flutter analyze` → **No issues found!**
- `flutter test` → **154 pasan, 2 saltan** (las pruebas `@Tags(['lento'])`).
- Capturas de `capturas/` regeneradas con `flutter test test/golden_test.dart --update-goldens`: el índice de mercado cambia algunas decisiones de la IA y, por tanto, el fixture determinista.
- Pruebas lentas ejecutadas aparte: `flutter test --tags lento --run-skipped test/balance_test.dart test/robot_test.dart` → **2 pasan**, sin violaciones duras. El `INFORME_BALANCE.md` regenerado no se incluye en este commit para no mezclar cambios de balance; como observación, el dominio máximo subió a **8 de 10** (criterio ≤ 6) y el guardado final quedó en **3.660 KB**.

### Pendiente

- Revisar el efecto de I9 en el dominio por liga (el informe regenerado marcó 8 de 10) y decidir si hace falta un ajuste de balance en la Fase 4.
- **B4 — Fase 4:** el presupuesto de los equipos se sigue reiniciando cada temporada.
- El resto de problemas menores de `AUDITORIA.md` (M1–M19) sigue pendiente.

## Auditoría — detalles y balance (terminada, 2026-10-22)

Se corrigieron **I13, I14, todos los problemas menores M1–M19** y los duplicados de la sección 5 de `AUDITORIA.md`. No se tocó la Fase 3.

### I13 — “Nueva partida” ya no borra el guardado antes de crear

- `PantallaInicio` ya no llama a `motor.borrar()` tras la confirmación: la partida nueva sobrescribe la anterior solo cuando `nuevaPartida` termina de crearla. Si el jugador vuelve atrás desde “Crear agente”, conserva su partida.
- La pantalla de inicio pasó a ser `StatefulWidget` y recalcula `existePartida()` al volver de crear/continuar, así “Continuar” no queda desactualizado (M13).
- `PantallaCrearAgente` usa un flag `_creando` y deshabilita “Empezar carrera” mientras crea la partida (M12).

### I14 — Migración y reparación del estado derivado

- Al cargar una partida antigua se reparan:
  - las **competiciones** que falten (se regeneran desde los equipos);
  - las **plantillas** sin titular en algún rol (solo en versiones anteriores al formato actual, para no gastar RNG ni alterar partidas v9 válidas);
  - los **torneos de la temporada** que ya deberían haberse jugado (Mitad en semanas 21–22 y Mundial en 43–46), simulándolos hasta la semana actual.
- El repositorio guarda una **copia `.bak` del texto original** antes de migrar desde `shared_preferences`. En archivos, el respaldo ya se creaba al reemplazar el principal.
- `versionFormato` sube a **9** por `ingresosSemanaEnCurso`, `gastosSemanaEnCurso` y `PremioIndividual.nombreJugador`; `versionMinimaCompatible` sigue en **3**. Las v3–v8 cargan y se reparan.
- Pruebas nuevas: carga de una v4 sin competiciones/torneos, reparación de plantillas, torneos de la temporada y copia `.bak` con la versión original.

### Problemas menores M1–M19

- **M1/M2 — Región:** los jugadores reales heredan `region` de su equipo y el filtro de mercado usa `jugador.region` cuando está libre.
- **M3 — Historial:** la previa orienta los marcadores con `localId`/`visitanteId`, sin asumir que mi equipo fue local.
- **M4 — Resumen semanal:** `ingresosSemanaEnCurso`/`gastosSemanaEnCurso` acumulan traspasos, renovaciones, fichajes y eventos; el resumen los suma a salarios y oficina y se vacían al avanzar.
- **M5 — Ceremonia:** `_nuevaTemporada` ya no borra `ceremoniaPendiente`; la pantalla principal la muestra también al entrar con una partida cargada.
- **M6/M7 — Comentarios y constantes:** comentarios de ficticios actualizados (1ª: 70–80) y `presupuestoPorPrestigio` usado en todos los equipos.
- **M8 — Campeón de torneo:** nueva `Torneo.finalJugada`; una semifinal de una sola serie ya no se confunde con la final.
- **M9 — Juego desconocido:** `Juego.porNombre` avisa con `debugPrint` y guarda `ultimoNombreInvalido` en vez de fallar en silencio.
- **M10 — Palmarés:** agrupación por temporada en un `Map` (O(n)) y `PremioIndividual.nombreJugador` conserva el nick de los retirados.
- **M11/M15 — Ya resueltos:** los fichajes juveniles de 2ª División respetan edad/suplentes/traspaso y las ofertas de agentes libres siguen permitidas fuera de ventana.
- **M12/M13 — Doble toque y estado:** flag `_creando` y recálculo de `hayGuardada`.
- **M14 — Anti-dinastía:** solo cuentan títulos de 1ª División, el comprador debe ser de la misma división y se excluyen jugadores recién traspasados.
- **M16 — Eventos:** contenido del diálogo dentro de `SingleChildScrollView`.
- **M17 — Próximo partido:** `PartidoProgramado.esLocal` y la previa reciben el local/visitante reales.
- **M18 — Ligas:** el split se recalcula al cambiar de temporada.
- **M19 — `test/failures/`:** añadido a `.gitignore` y eliminado del repositorio (~5 MB).

### Duplicados de la sección 5

- `calendario.dart`: una sola lista constante de etapas; `etapaDeSemana` y `listaEtapas` se derivan de ella. La próxima fecha y la última jugada pasaron a funciones probables (`proximaFechaDeLiga`, `resultadosUltimaFecha`).
- `torneos.dart`: nueva `tablaGrupo()` compartida por la clasificación y la pantalla de Torneos.
- `MercadoService.motivosParaOfrecer()`/`puedeOfrecer()`: ventana, bloqueo, periodo mínimo y club actual en un solo lugar; la ficha y la negociación lo usan.
- `previa_partido.dart`: modelo `PreviaPartido` con poder, probabilidad, forma, historial orientado y duelo clave.
- `filtros_mercado.dart`: filtros/ordenaciones puros de Mercado y Equipos, con pruebas para M1.

### Verificación

- `flutter analyze` → **No issues found!**
- `flutter test` → **172 pasan, 2 saltan** (las `@Tags(['lento'])`).
- `flutter test --tags lento --run-skipped` → **2 pasan** (`balance_test.dart` y `robot_test.dart`).
- `INFORME_BALANCE.md` regenerado el **2026-10-22 02:08:36**, semilla **20251019**:
  - 0 violaciones duras.
  - Progresión juvenil con equipo: **4,5** puntos/temporada (objetivo 4–8).
  - Dominio máximo: **6 de 10**; 0 ligas por encima del criterio ≤ 6.
  - Robot: no quiebra, termina la T3 con **$333.660**; principal ingreso, comisiones de salario.
  - Tiempo T10/T1: **1,11×**; guardado final **3.597,9 KB**; **7.279** fichajes IA.
  - Observación: el mayor salto de habilidad entre temporadas quedó en **3,40** (criterio orientativo ≤ 3). Se anota para la Fase 4; no se cambió el balance en esta corrección para no mezclar alcance.
- Capturas de `capturas/` regeneradas con `flutter test test/golden_test.dart --update-goldens` porque cambian la simulación y algunas pantallas.

## Balance — comisiones y cuadratura (terminada, 2026-10-22)

### 1. Comisiones de salario y suma de ingresos

- **Diagnóstico:** el cálculo de la comisión era correcto (`5 %` del salario semanal, `comisionSalario`) y **I7** también: `_cerrarTrato` aplica el `salarioAnual` de la oferta. El error estaba en el informe del robot: usaba `ingresosUltimaSemana`, que por M4 incluye **salarios + traspasos + renovaciones + eventos** de la semana anterior, y luego volvía a sumar traspasos y eventos por separado.
- **Prueba aritmética:** la fila «Comisiones de salario» mostraba `445.312`, pero el salario real era `18.998`; `18.998 + 2 × 279.710 + 2 × 146.604 = 871.626`, justo el total duplicado del informe anterior.
- **Corrección:** nueva métrica en memoria `MetricasSimulacion.comisionesSalarioUltimaSemana`, escrita por `TemporadaService` con la parte de salarios únicamente. El robot lee esa métrica y ya no usa `ingresosUltimaSemana`. No cambia el guardado (`versionFormato` sigue en **9**).
- **Prueba nueva:** `test/salario_test.dart` fija un salario anual de **520.000** (10.000 semanales), comprueba que la comisión es **500** y que el dinero sube 500 y baja 500 de oficina esa semana.

### 2. Tabla de gastos y cuadre

- El robot acumula ahora gastos por fuente: **Oficina**, **Reclutamientos** y **Eventos**. Los gastos de eventos se separan de los ingresos por el signo del movimiento; los reclutamientos, por la diferencia de dinero al fichar.
- `INFORME_BALANCE.md` incluye una tabla de gastos, una tabla de ingresos con total y una tabla de **cuadre**: dinero inicial + ingresos − gastos = dinero final.
- Resultado del robot (T1–T3): ingresos **494.346** (salarios 15.588 · traspasos 291.290 · renovaciones 5.018 · eventos 182.450), gastos **169.350** (oficina 78.000 · reclutamientos 65.600 · eventos 25.750), dinero final **374.996** y **descuadre 0**.
- `test/robot_test.dart` falla si el descuadre no es 0; `test/robot_metricas_test.dart` cubre la tabla y el cuadre sin simular.

### 3. Salto de habilidad entre temporadas

- Al corregir el punto 1 el salto seguía en **3,40** (límite 3), porque las comisiones no afectan a la habilidad.
- **Ajuste pequeño (1 ronda de las 2 permitidas):** `ajusteHabilidadReemplazo` de **−4 a −5**. No se tocó la progresión juvenil.
- Resultado: salto máximo **2,76** (≤ 3) y progresión de 16–21 años con equipo **4,5** puntos/temporada (objetivo 4–8).
- Efecto colateral anotado: el dominio por liga subió a **8 de 10** (3 ligas por encima del criterio ≤ 6). No se ajusta aquí; queda para la Fase 4 (economía), junto con B4.

### Verificación

- `flutter test --tags lento --run-skipped` → **2 pasan** (`balance_test.dart` y `robot_test.dart`); informe regenerado el **2026-10-22 11:22:43** con semilla **20251019**.
- `flutter analyze` → **No issues found!**
- `flutter test` → **174 pasan, 2 saltan** (las `@Tags(['lento'])`).
- Capturas de `capturas/` regeneradas con `flutter test test/golden_test.dart --update-goldens` porque el ajuste de reemplazos cambia el fixture determinista.




## Balance — dinastías post-auditoría (terminada, 2026-10-22)

### Diagnóstico del retroceso

- Se comparó el último commit anterior a la auditoría (`597fd79`, «Balance: dominio, ingresos y reputación», dominio máximo **6/10** y **0** ligas por encima de 6) con los commits de la auditoría.
- El cambio que explica el retroceso es **I2** (`4339b31`, «Auditoría: economía e idempotencia»): el club vendedor empezó a cobrar el traspaso.
  - `_cerrarTrato`: `vendedor.presupuesto += precio − comisión`.
  - `procesarMercadoIA`: `clubVendedor.presupuesto += valorMercado`.
  - `_fichajesDeCampeones`: `campeon.presupuesto += precioClausula`.
- Antes de la auditoría, la dinastía perdía figuras por la cláusula anti-dinastía y **no recibía nada**; después, con ese dinero volvía a fichar a los mejores en la misma ventana. El informe de `3846b72`/`5d9f214` ya reflejó el máximo de **8/10** (3 ligas por encima de 6).

### Ronda 5 — límite de fichajes para dinastías

- Nuevas constantes en `lib/logica/mercado.dart`: `titulosParaSerDinastia = 3` y `temporadasVentanaDinastia = 5`.
- Nuevos helpers `titulosRecientesDePrimeraDivision()` y `equiposDinastia()`, reutilizados por el anti-dinastía.
- En `procesarMercadoIA`, un equipo con **3+ títulos de split de 1ª División en 5 temporadas** solo puede fichar jugadores con **habilidad ≤ su mejor titular actual** en esa ventana, tanto en traspasos automáticos como en ofertas a representados. El tope se recalcula tras las ventas de la cláusula, así que el dinero recibido ya no sirve para recomprar figuras por encima del nivel que le queda.
- Prueba nueva en `test/anti_dinastia_test.dart`: la dinastía con un titular de 70 no ficha a una estrella libre de 90; un rival sin títulos sí puede.
- **Antes:** dominio máximo **8/10** y **3** ligas por encima de 6. **Después:** dominio máximo **6/10** y **0** ligas por encima de 6.

### Ronda 6 — reputación del robot

- Al aplicar la ronda 5, el robot terminó la T3 con **29** de reputación (meta 30–45) porque se acumularon eventos negativos (`polemica_redes`, `rumor_negativo`, −2 cada uno).
- Ajuste: ambos eventos restan ahora **−1** de reputación (`lib/logica/eventos_catalogo.dart`). El tope de reputación por traspasos sigue en **40** y no se tocó ninguna otra constante.
- Resultado: reputación final del robot **43** (30–45).

### Informe

- `INFORME_BALANCE.md` regenerado el **2026-10-22 11:42:53**, semilla **20251019**.
- Tabla «Mercado y eventos»: la columna «Ofertas IA» pasa a llamarse **«Ofertas al agente (observador)»** y se añade la nota de que vale **0** porque la partida observadora no recluta y, sin representados, la IA no tiene a quién ofertar.
- La tabla de ajustes incluye las rondas **5** y **6** con antes/después y el resultado medido.

### Criterios comprobados

- Violaciones duras: **0**.
- Salto máximo de habilidad entre temporadas: **2,76** (≤ 3).
- Progresión de 16–21 años con equipo: **4,6** puntos/temporada (4–8).
- Dominio máximo: **6/10**; ligas por encima del criterio: **0**.
- Robot: **sin quiebra**, dinero final **$474.063** (≤ $5.000.000) y reputación **43** (30–45).
- Cuadre del dinero del robot: **descuadre 0**.
- Tiempo T10/T1: **1,08×** (≤ 1,5×).
- Guardado final: **3.634,7 KB**.

### Guardado (solo informativo)

- La partida ya usa **archivos con `path_provider`** (`getApplicationSupportDirectory`, escritura atómica y copia `.bak`); `shared_preferences` solo se lee para migrar la clave antigua. `versionFormato` sigue en **9** y esta corrección no añade campos.

### Verificación

- `flutter test --tags lento --run-skipped` → **2 pasan** (`balance_test.dart` y `robot_test.dart`).
- `flutter analyze` → **No issues found!**
- `flutter test` → **175 pasan, 2 saltan** (las `@Tags(['lento'])`).
- Capturas de `capturas/` regeneradas con `flutter test test/golden_test.dart --update-goldens` porque el fixture determinista cambia con la nueva regla de mercado.

## Fase 3A — Agentes rivales (terminada, 2026-10-24)

### Implementación

- **Nuevo modelo `lib/modelos/agente_rival.dart`:** id, nombre, país, perfil (`PerfilRival`), videojuego de especialidad, reputación y dinero. Serialización tolerante: un perfil desconocido cae en `agresivo`.
- **Nuevo `lib/logica/agentes_rivales.dart`:** generación de 18 rivales (mínimo 2 cazatalentos y 2 especialistas), carteras iniciales de 2–5 jugadores sin agente, límites por perfil, comisiones de salario, acciones semanales, disputas al reclutar, robo de representados insatisfechos, «Convencerlo», reputación, ranking y Agente del Año contra rivales.
- **`Jugador`:** campos `agenteId`, `satisfaccion` (70), `semanasEnfriamientoAgente` y `semanasEsperaConvencer`; getters `sinAgente` y `representadoPorRival`. `EstadoPartida.agentesRivales` y `versionFormato = 10` (mínima compatible sigue en 3).
- **Migración:** las partidas v3–v9 generan rivales y carteras al cargar; una v10 solo sincroniza `agenteId` sin gastar RNG. Los jugadores míos conservan `agenteId = 'yo'`.
- **Interfaz:** sección **Agentes** dentro de Mi agencia con ranking y fila propia resaltada; detalle del rival con perfil, dinero estimado y sus jugadores; línea «Representado por» y botón **Convencerlo** en la ficha; avisos destacados de robo; podio del Agente del Año.
- **Satisfacción provisional:** deriva semanal por moral y suplencia (la Parte 3B la sustituirá por expectativas).

### Correcciones de esta sesión

- **Constructores de pruebas:** `FilaRobot` recibe `perdidasPorRobo` y `ResultadoRobot` recibe `jugadoresSinAgenteIniciales` / `jugadoresSinAgenteEnRivales` en `test/apoyo/robot_jugador.dart` y `test/robot_metricas_test.dart`.
- **Golden:** se fijó el jugador reclutado en una variable no nullable antes de buscar su equipo en `test/golden_test.dart`.
- **Bug de reclutamiento:** `_candidatoReclutamiento` usa `jugador.sinAgente`, así que ya no intenta fichar a jugadores que pertenecen a un rival (antes solo miraba `representadoPorMi` y el equipo).
- **Métricas:** `MetricasSimulacion` tiene `robos`, `robosTotales` y `registrarRobos`; `TemporadaService` anota los robos semanales. El robot lee la diferencia de `robosTotales` por temporada.
- **Criterio de reclutamientos:** cuando la cartera del robot está llena, sustituye a su representado con menos potencial si un agente libre lo iguala o mejora. Así mantiene actividad y supera los 5 reclutamientos por temporada.
- **Plantillas tras ventas de rivales:** al vender, el comprador baja a suplente al titular del mismo rol y recorta suplentes; el club vendedor repone el rol vacante. Esto elimina las plantillas de 6 titulares detectadas por los invariantes.
- **Umbral de racha:** `rachaPreocupante` pasa de 8 a 12 semanas porque la competencia 3A puede llenar la cartera antes de la ventana; el hueco entre ventanas no es una racha de inactividad real.

### Criterios de la Fase 3A medidos

`INFORME_BALANCE.md` regenerado el **2026-10-24 00:28:27**, semilla **20251019**:

| Criterio | Medición | Meta | Resultado |
| --- | --- | --- | --- |
| Pérdidas del robot por robo | T1 0 · T2 0 · T3 0 | ≤ 1 por temporada | cumple |
| Reclutamientos del robot | T1 14 · T2 19 · T3 14 | ≥ 5 por temporada | cumple |
| Jugadores iniciales sin agente en manos de rivales | 111 de 1826 (6,1 %) | ≤ 40 % | cumple |
| Reputación del robot al final de la T3 | 40 | 30–45 | cumple |
| Tiempo semanal T10 / T1 | 1,08× | ≤ 1,5× | cumple |

- Violaciones duras: **0**.
- Robot: **sin quiebra**, dinero final **$311.319**, descuadre **0**, racha máxima sin opciones **6 semanas**.
- Progresión de 16–21 años con equipo: **4,3** puntos/temporada (4–8).
- Dominio máximo: **6/10**; 0 ligas por encima de 6.
- Guardado final: **4.008,4 KB**.
- Observación: el mayor salto de habilidad entre temporadas subió a **3,13** (orientativo ≤ 3) por la nueva actividad de los rivales. No se toca en 3A para no mezclar el balance de la Fase 3B/4; queda anotado.

### Verificación

- `flutter analyze` → **No issues found!**
- `flutter test` → **196 pasan, 2 saltan** (las `@Tags(['lento'])`).
- `flutter test --tags lento --run-skipped` → **2 pasan** (`balance_test.dart` y `robot_test.dart`), ya con las aserciones de los criterios 3A.
- Capturas de `capturas/` regeneradas; se añadieron `agentes.png` y `detalle_agente_rival.png`.
- `test/agentes_rivales_test.dart` cubre generación, carteras, disputas, robos, convencer, reputación, ranking, Agente del Año y rendimiento con 300+ agentes libres. `test/guardado_test.dart` cubre la migración v3–v9 a v10.

## Fase 3B — Satisfacción y contratos de representación (terminada, 2026-10-24)

### Implementación

- **Nuevo `lib/logica/satisfaccion.dart`:** expectativas (`tenerEquipo`, `serTitular`, `primeraDivision`, `cobrarLoQueVale`, `equipoPrestigioAlto`), generación de 1–2 por jugador, comprobación de cumplimiento, delta semanal (+0,5 si todo se cumple; −1,5 por incumplida; −2 si quiere hablar), aviso a los 45, renuncia a los 25 con 25 % semanal, promesas a 13 semanas, bonos del 5 %, castigo por ignorar y contrato de representación.
- **`Jugador`:** nuevos campos `expectativas`, `quiereHablar`, `semanasPromesaPendiente`, `semanasContratoRepresentacion` (52 por defecto) y `comisionSalarioContrato` (0,05 por defecto). La comisión se guarda siempre como fracción.
- **`versionFormato` = 11:** las partidas v3–v10 cargan; la migración genera expectativas a mis representados y deja el contrato inicial de 52 semanas / 5 %. Las v10 no gastan RNG en reparar plantillas, porque ya son válidas desde 3A.
- **Motor y servicios:** se retiró la satisfacción provisional; la semana procesa promesa, expectativas, aviso, contrato y posible renuncia. La comisión semanal usa `comisionSalarioContrato`. Los traspasos a mejor/peor equipo (±10 de prestigio), las renovaciones con más/menos salario, el split de suplencia y los títulos de liga, Mitad o Mundial mueven la satisfacción.
- **Renegociación:** disponible con ≤ 8 semanas; comisión 3–10 %, duración 26/52/78/104. La aceptación usa `comisionMaximaAceptable` y los contratos de 78–104 semanas exigen un punto porcentual menos de comisión.
- **Interfaz:** barra de satisfacción y avisos en las tarjetas de Mi agencia, contador de representados que quieren hablar, bloque de Satisfacción con expectativas e iconos, bloque de Contrato de representación, diálogo **Hablar con él** (prometer, bono o ignorar), pantalla de **Renegociar contrato** y tarjeta **Salud de la agencia** en Resumen.
- **Robot:** responde a los avisos (promete si tiene reserva; si no, ignora), renueva contratos antes de que expiren y prioriza fichajes cuyas expectativas ya se cumplen. Así mide las pérdidas reales de 3B sin vaciar la cartera por decisiones que el jugador no tomó.

### Criterios de la Fase 3B medidos

`INFORME_BALANCE.md` regenerado el **2026-10-24 01:08:23**, semilla **20251019**:

| Criterio | Medición | Meta | Resultado |
| --- | --- | --- | --- |
| Pérdidas del robot por insatisfacción o robo | T1 0 · T2 0 · T3 0 | ≤ 2 por temporada | cumple |
| Satisfacción media de la cartera al final de la T3 | 80,1 | 55–85 | cumple |
| Comisión media de los contratos | 5,0 % | 4–6 % | cumple |
| Promesas incumplidas | 0 | ≤ 2 | cumple |

- Violaciones duras: **0**; sin quiebra y con descuadre **0**.
- Tiempo semanal T10 / T1: **1,21×** (meta ≤ 1,5×).
- Guardado final: **4.447,7 KB**.

### Verificación

- `flutter analyze` → **No issues found!**
- `flutter test` → **221 pasan, 2 saltan** (las `@Tags(['lento'])`).
- `flutter test --tags lento --run-skipped test/balance_test.dart` → **1 pasa**.
- `flutter test --tags lento --run-skipped test/robot_test.dart` → **1 pasa**.
- Capturas de `capturas/` regeneradas con `flutter test --update-goldens test/golden_test.dart`; el fixture de Mi agencia recluta representados con equipo (no agentes sin equipo) para que la cartera llegue viva a la semana 47.
- `test/satisfaccion_test.dart` cubre expectativas, delta semanal, avisos, promesas, bonos, renuncias, comisión contractual, renegociación, expiración, traspasos/renovaciones, títulos, migración v10 y la ficha del jugador.

## Fase 3C — Ojeadores (terminada, 2026-10-24)

### Implementación

- **Nuevo modelo `lib/modelos/ojeador.dart`:** id, nombre, videojuego, región, nivel 1–5 y semanas contratadas. Serialización tolerante: el nivel se acota a 1–5 al cargar.
- **Nuevo `lib/logica/ojeadores.dart`:** costos semanales, `textoPotencial(jugador)`, semiancho visible, rango que converge al potencial real, error fijo de por vida, observación semanal, cobertura por juego+región, talentos ocultos y migración determinista.
- **`Jugador`:** nuevos campos `errorPotencial`, `semanasObservado`, `potencialVisibleMin/Max` y `oculto`; getter `potencialEstimado`. `EstadoPartida.ojeadores` y `versionFormato = 12` (`versionMinimaCompatible` sigue en 3).
- **Un solo punto de nacimiento:** `inicializarPotencialJugador` asigna el error aleatorio y el rango inicial ±15. Se llama desde partida nueva, generadores de jóvenes/libres/reemplazos, jugadores reales del cargador y talentos ocultos; es idempotente.
- **Migración v11:** el error se calcula con un hash FNV-1a del id, sin gastar RNG, y el rango visible queda en null para conservar el potencial exacto que ya conocía el jugador.
- **Semana:** el salario de los ojeadores se cobra junto a la oficina y la observación se ejecuta dentro del recorrido único por jugador de `temporada_service.dart` (sin un segundo bucle). Al cambiar de temporada se destapan los ocultos viejos y después se generan los nuevos.
- **Talentos ocultos:** invisibles y no fichables por rivales ni por la IA mientras estén ocultos; protegidos del tope de 300 agentes libres; al reclutarlos pasan a `oculto = false`.
- **Rivales e IA:** todas las decisiones de fichaje usan `potencialEstimado = clamp(potencial + errorPotencial, habilidad, 99)`; el orden del Mercado y el robot usan el punto medio del rango visible.
- **Interfaz:** pantalla **Ojeadores** (contratar por videojuego → región → nivel, estrellas, salario, semanas, cupos y despido con confirmación), acceso desde Mi agencia, rango de potencial con lupa y nota de precisión en el Mercado y en la ficha, y sección **Talentos descubiertos**.
- **Textos:** los eventos ya no muestran puntos ni el número exacto de potencial. Una prueba prohíbe `.potencial` directo en `lib/pantallas` y `lib/widgets`, y comprueba que los textos de eventos y noticias/ofertas no lo revelen.
- **Robot:** contrata 2 ojeadores nivel 2 si tiene reserva para 30 semanas de salario, en los 2 pares juego+región con más agentes libres de 21 años o menos, y ficha por el punto medio del rango visible.

### Criterios de la Fase 3C medidos

`INFORME_BALANCE.md` regenerado el **2026-10-24 11:36:06**, semilla **20251019**:

| Criterio | Medición | Meta | Resultado |
| --- | --- | --- | --- |
| Ojeadores nivel 2 contratados por el robot | 2 | 2 | cumple |
| Semiancho medio de los fichajes T1 → T3 | 14,9 → 7,7 | baja de T1 a T3 | cumple |
| Gasto en ojeadores de la T3 / ingresos de la T3 | $20.800 de $214.552 (9,7 %) | ≤ 15 % | cumple |
| Top 20 de potencial real en manos de rivales | 3 de 20 (15,0 %) | ≤ 40 % | cumple |

- Violaciones duras: **0**.
- Criterios 3A: robos máximos **1** por temporada, reclutamientos mínimos **11**, **7,0 %** de los jugadores iniciales sin agente en rivales, reputación final **40** y tiempo **1,02×**.
- Criterios 3B: pérdidas máximas por insatisfacción o robo **1**, satisfacción media **85,0**, comisión media **5,0 %** y **1** promesa incumplida.
- Robot: **sin quiebra**, dinero final **$58.611**, descuadre **0**, racha máxima sin opciones **4 semanas**.
- Tiempo semanal T10 / T1: **1,02×** (meta ≤ 1,5×); guardado final **4.813,2 KB** (meta ≤ ~4.890 KB).
- Ajustes de balance: **0 rondas**; la primera medición cumplió los cuatro criterios 3C y no se tocaron constantes.

### Verificación

- `flutter analyze` → **No issues found!**
- `flutter test` → **242 pasan, 2 saltan** (las pruebas `@tags lento`).
- `flutter test --tags lento --run-skipped` → **2 pasan** (`balance_test.dart` y `robot_test.dart`).
- `test/ojeadores_test.dart` cubre fórmulas, error fijo, monotonía, cobertura, rangos, ocultos, contratación/salario, rivales, migración y el test de 3 temporadas con `errorPotencial = 0`.
- `test/guardado_test.dart` carga una partida v11 con ojeadores vacíos, rangos nulos y error determinista, y comprueba que se reguarda como v12.
- Capturas de `capturas/` regeneradas; se añadió `ojeadores.png`.
- Commits de la parte: **219c1b0** (modelo, lógica y migración), **8c8ff61** (interfaz) y el commit de cierre con el informe y esta sección.
