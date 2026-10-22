# PLAN FASE 3: AGENTES RIVALES, SATISFACCIÓN, OJEADORES, STAFF Y ACADEMIA — ESPORTS AGENT

> Este documento **reemplaza la Fase 3** de `PLAN.md`.
> Las reglas de la sección 0 de `PLAN.md` siguen vigentes (paquetes, comentarios en español,
> confirmaciones, `flutter analyze`, etc.). No se necesitan paquetes nuevos: todo usa
> `ChangeNotifier`, `dart:convert` y los widgets ya existentes.
>
> La Fase 3 se divide en **5 partes (3A a 3E)**. OpenCode debe hacer **una sola parte por sesión**,
> en orden. Antes de empezar cada parte: leer este archivo, revisar el código existente y mostrar
> la lista de archivos a crear/modificar.

---

## RESUMEN DE LAS PARTES

| Parte | Contenido | Resultado |
|---|---|---|
| **3A** | Agentes rivales IA con nombre, perfil, reputación y cartera; disputas por jugadores sin agente y robo de representados insatisfechos | Hay competencia: el mundo de los agentes está vivo |
| **3B** | Expectativas y satisfacción (0–100) de cada representado, contratos de representación con duración y comisión negociables | Debes cuidar a tus jugadores o se van |
| **3C** | Ojeadores por juego y región; el potencial se oculta tras un rango estimado que mejora con nivel y semanas de seguimiento | El talento hay que descubrirlo |
| **3D** | Staff de la agencia: abogado, relaciones públicas y preparador, con salario semanal y nivel 1–5 | Inviertes en tu agencia para jugar mejor |
| **3E** | Academia: reclutar jóvenes de 15–17, entrenarlos y colocarlos en equipos de 2ª División | Tu propia cantera de talento |

**Orden y dependencias entre partes:**

- **3A** introduce el campo `Jugador.satisfaccion` con una deriva semanal **provisional** (basada en moral y suplencia). **3B** la sustituye por el sistema completo de expectativas. Así el robo de representados ya funciona en 3A sin esperar a 3B.
- **3C** cambia cómo se ve el potencial. Los rivales de 3A usan el mismo `errorPotencial` fijo que el jugador (semiancho inicial ±15), así no se quedan con todos los mejores jóvenes.
- **3D** y **3E** dependen de 3B (la satisfacción reacciona a traspasos, renovaciones y progresión).
- Cada parte sube `versionFormato`: **10 (3A), 11 (3B), 12 (3C), 13 (3D), 14 (3E)**. `versionMinimaCompatible` sigue en **3** y las partidas v3–v9 siguen cargando.
- **Al final de cada parte (obligatorio):** `flutter analyze`, `flutter test` completo, `flutter test --tags lento --run-skipped`, regenerar `INFORME_BALANCE.md` con el robot y regenerar las capturas golden si cambió la interfaz. Así se detectan retrocesos de balance y rendimiento a tiempo, sin dejarlos para una sesión aparte.

---

# PARTE 3A — AGENTES RIVALES

## 3A.1 Qué ve el jugador

- **Ranking de agentes:** nueva sección **"Agentes"** dentro de **Mi agencia** (subpestaña o sección con encabezado), **sin añadir una 6ª pestaña a la barra inferior**. Muestra el ranking conmigo incluido: posición, nombre, perfil (ícono), reputación, número de representados y valor de cartera; tu fila resaltada en violeta.
- **Detalle del agente rival:** nombre, país, perfil explicado ("Paga caro por estrellas", "Caza jóvenes con potencial"...), reputación, dinero estimado y sus 5 jugadores más valiosos (tarjetas de jugador). Botón "Ver jugador" en cada tarjeta.
- **Detalle del jugador:** si tiene agente rival, una línea "Representado por: «nombre» (perfil)" y el botón **Convencerlo** (con confirmación y la probabilidad de éxito mostrada). Si no tiene agente, el botón **Reclutar** ya existente.
- **Disputa al reclutar:** diálogo "«Rival» también quiere representar a «nick»" con el resultado: te elige a ti o se va con el rival.
- **Robo de un representado:** noticia roja + aviso destacado: "«nick» deja tu agencia y firma con «rival»."
- **Ceremonia de fin de temporada:** el premio **Agente del Año** ahora se disputa contra los rivales (muestra el podio de los 3 mejores).

## 3A.2 Reglas y fórmulas (constantes en `lib/logica/agentes_rivales.dart`)

**Definición única — agente libre:** en todo el documento, "agente libre" es un **jugador sin agente** (`agenteId == null` y `representadoPorMi == false`), tenga o no equipo. Un jugador que no tiene equipo se llama siempre **jugador sin equipo**; nunca se usa "libre" para las dos cosas a la vez.

**Generación (al crear partida y al migrar partidas viejas):**

- `agentesRivalesMin = 15`, `agentesRivalesMax = 25` → se generan `numAgentesRivales = 18` (dentro del rango).
- `reputacionRivalMinima = 20`, `reputacionRivalMaxima = 90` (uniforme).
- Dinero inicial: `dineroRivalInicial = reputacion × dineroRivalPorReputacion`, con `dineroRivalPorReputacion = 2500`.
- Perfiles (`enum PerfilRival`): **agresivo, cazatalentos, negociador, comercial, conservador, especialista**. Garantizar al menos 2 cazatalentos y 2 especialistas; el especialista elige un videojuego al azar.
- Cartera inicial: cada rival representa `2 + azar(0..3)` jugadores sin agente (`agenteId == null` y no representados por mí) y que lo acepten (misma regla que el jugador: `reputacion ≥ habilidad − 40`). Primero sin equipo, después suplentes o jugadores de 2ª División. Si no hay suficientes que lo acepten, se queda con menos.

**Cartera máxima por perfil** (`maxCarteraPorPerfil`). Ningún rival ficha por encima de su máximo, ni al generarse ni en acciones semanales ni en disputas; si su cartera está llena, solo puede vender o renovar:

| Perfil | Máximo de cartera |
|---|---|
| agresivo | 15 |
| cazatalentos | 20 |
| negociador | 12 |
| comercial | 20 |
| conservador | 8 |
| especialista | 12 |

**Acción semanal de cada rival (al final de `avanzarSemana`, orden barajado):**

1. Cobra su comisión de salario por sus representados con equipo.
2. Con `probActividadRivalSemanal = 0.20` hace **una** acción según su perfil:
   - **Agresivo:** ficha al jugador sin agente con mayor habilidad ≥ 70 (paga `0.05` de su valor: 5 %). Comisión de salario 0,06.
   - **Cazatalentos:** ficha al jugador sin agente con mayor margen `potencialEstimado − habilidad ≥ 12` y edad ≤ 20. Comisión 0,05.
   - **Negociador:** vende a un representado a un equipo interesado (en ventana) y cobra su 0,10 (10 %); si no, renueva contratos de sus jugadores. Comisión 0,04.
   - **Comercial:** ficha barato (valor < $100.000) y vende rápido. Comisión 0,03.
   - **Conservador:** solo ficha si su dinero > 10 × el costo. Comisión 0,04.
   - **Especialista:** solo trabaja su videojuego. Comisión 0,05.
3. Con `probIntentoRoboPorRivalSemanal = 0.08` intenta **robar** a un representado mío insatisfecho (ver abajo).

**Reputación de los rivales (mismas reglas y mismo techo que el jugador):**

- La reputación de un rival se mueve con las mismas fórmulas que la tuya y siempre se acota a **0–100** (el mismo techo que el jugador).
- **Ganancias por sus clientes:**
  - Traspasos: `reputacionPorTraspaso(...)` (+2 normal, +3 élite; rendimientos decrecientes a partir de 30/40, igual que el jugador).
  - Títulos: +2 por título de mitad y +5 por Mundial (`efectoCampeonReputacionMitad = 2`, `efectoCampeonReputacionMundial = 5`).
  - Premios individuales de sus clientes: +3 (`efectoPremioReputacion`); si un rival gana el Agente del Año: +5 (`reputacionAgenteDelAnio`).
- **Pérdidas:** las mismas que puede sufrir el jugador (eventos negativos) y `penalizacionRivalArruinado = 1` por temporada si queda con dinero < 0. No se añaden penalizaciones nuevas por perder un cliente.

**Disputa por un jugador sin agente (cuando yo recluto):**

- Con `probDisputaRivalBase = 0.25`, un rival con reputación ≤ mía + `ventajaDisputaRivalMax = 25` y con cartera por debajo de su máximo quiere al mismo jugador.
- Se compara el **atractivo** de cada agente:
  ```
  atractivo = reputacion + (0.05 − comisionCobrada) × 200 + bonusEspecialista + azar(0..10)
  ```
  `bonusEspecialista = 3` si el jugador es del videojuego del especialista (constante `bonusEspecialistaAtractivo = 3`). `azar` uniforme con `azarAtractivoMax = 10`.
- Gana el de mayor atractivo. Si gano yo, pago la comisión inicial de `0.05` (5 %) y lo represento (como siempre). Si gana el rival, no pago nada, el rival lo ficha pagando su `0.05` y el jugador queda con `semanasEnfriamientoAgente = 26` (`semanasEnfriamientoCambioAgente = 26`); durante esas semanas no puede volver a cambiar de agente.

**Robo de un representado mío (poaching):**

- Condiciones: `satisfaccion < satisfaccionMinimaRobo = 35` y `semanasEnfriamientoAgente == 0`.
- Probabilidad de éxito:
  ```
  probRobo = clamp(0.25 + (atractivoRival − atractivoMio) / 50, 0.05, 0.75)
  ```
- Si sale: el jugador pasa al rival (`agenteId = rival.id`, `representadoPorMi = false`, `semanasRepresentado = 0`, `semanasEnfriamientoAgente = 26`), con noticia y aviso destacado.

**Convencer a un jugador de un rival (botón en el detalle):**

- Mismo cálculo invertido: `probConvencer = clamp(0.20 + (atractivoMio − atractivoRival) / 50, 0.05, 0.60)`.
- Sin costo, con confirmación previa. Solo se puede intentar si `semanasEnfriamientoAgente == 0` y `semanasEsperaConvencer == 0`; si hay espera, el botón queda deshabilitado con "Podrás intentarlo de nuevo en N semanas".
- Si el intento **falla**, ese jugador queda con `semanasEsperaConvencer = semanasEsperaConvencerFallido = 13` (se descuenta 1 por semana). Un intento exitoso no deja esta espera.
- Al cambiar de agente (en cualquier dirección): `semanasEnfriamientoAgente = 26` (constante `semanasEnfriamientoCambioAgente = 26`) para evitar ping-pong.

**Reglas comunes:**

- Los rivales siguen las mismas reglas que el jugador: no ven información oculta (potencial real, ver 3C), respetan su dinero y las ventanas, y marcan `temporadaUltimoTraspaso` al vender.
- Si un rival queda con dinero < 0: no actúa y pierde 1 de reputación por temporada (`penalizacionRivalArruinado = 1`). No muere.
- **Ranking:** ordenado por `puntosRanking = reputacion + (valorCartera / 1000000).round()`, desempate por valor de cartera.
- **Agente del Año (semana 47):** gana el agente (yo o un rival) cuyos representados suman más puntos con los pesos ya existentes (Mundial 15, mitad 8, liga 5, premio individual 3, MVP 0,5). El ganador suma +5 de reputación (constante existente `reputacionAgenteDelAnio`), sea yo o un rival.

**Satisfacción provisional (hasta 3B):** `satisfaccion` baja 0,5/semana si `moral < 45` o es suplente, sube 0,5/semana si `moral > 75`; acotada 0–100. 3B la reemplaza por expectativas reales.

## 3A.3 Campos nuevos y guardado

| Modelo | Campo | Tipo | Valor por defecto en `fromJson` |
|---|---|---|---|
| Nuevo `lib/modelos/agente_rival.dart` | `AgenteRival` completo | — | `perfil` cae a `agresivo` si el texto no existe; `juegoEspecialidad` puede ser `null` |
| `Jugador` | `agenteId` | `String?` | `null` (= sin agente; `representadoPorMi` sigue mandando para mis jugadores) |
| `Jugador` | `satisfaccion` | `int` | `70` |
| `Jugador` | `semanasEnfriamientoAgente` | `int` | `0` |
| `Jugador` | `semanasEsperaConvencer` | `int` | `0` |
| `EstadoPartida` | `agentesRivales` | `List<AgenteRival>` | `[]` |

- `versionFormato` sube de **9 a 10**; `versionMinimaCompatible` sigue en 3.
- **Migración al cargar v3–v9:** se generan los rivales y se asigna `agenteId` a 2–5 jugadores sin agente (nunca a los míos). El reclutar/dejar de representar existente pasa a mantener `agenteId` en sincronía (`'yo'` o `null`).

## 3A.4 Pruebas a agregar (`test/agentes_rivales_test.dart` + `test/guardado_test.dart`)

- Se generan entre 15 y 25 rivales con ids y nombres únicos; el especialista tiene videojuego.
- La cartera inicial respeta `reputacion ≥ habilidad − 40`, nunca toca mis representados y no supera el máximo del perfil.
- Serialización ida y vuelta; una partida v9 carga con rivales generados y mis jugadores intactos.
- Disputa: gana el de mayor atractivo, solo paga el ganador, solo disputan rivales dentro de la ventaja de 25 y con cartera disponible; si gana el rival, el jugador queda con enfriamiento 26.
- Robo: solo con satisfacción < 35 y sin enfriamiento; tras el robo queda enfriamiento 26 y no puede volver a cambiar de agente.
- Convencer: probabilidad acotada 0,05–0,60; si falla deja `semanasEsperaConvencer = 13` y no se puede reintentar antes; si acierta, enfriamiento 26.
- Reputación de rivales: sube por traspasos, títulos y premios de sus clientes y baja por los mismos eventos negativos que el jugador, siempre con el techo 0–100.
- Ranking y Agente del Año comparan contra rivales.
- Rendimiento: paso semanal de los rivales con 300+ jugadores sin agente por debajo del umbral de tiempo de `test/rendimiento_test.dart`.

## 3A.5 Criterios de balance (robot e informe)

- El robot pierde **≤ 1 representado por temporada** por robo de rivales (con la satisfacción provisional).
- El robot sigue consiguiendo **≥ 5 reclutamientos por temporada** a pesar de la competencia.
- Al final de la T3, los rivales no poseen más del **40 %** de los jugadores que empezaron la partida sin agente.
- La reputación del robot sigue en **30–45 al final de la T3**.
- El tiempo semanal no crece más de **1,5×** con los rivales activos.

---

# PARTE 3B — SATISFACCIÓN Y CONTRATOS DE REPRESENTACIÓN

## 3B.1 Qué ve el jugador

- **Pestaña Mi agencia:** cada tarjeta muestra una barra de satisfacción (verde > 60, amarilla 40–60, roja < 40) y un aviso: amarillo "Quiere hablar contigo" (satisfacción < 45) o rojo "Riesgo de marcharse" (< 25). Contador de avisos en la parte superior.
- **Detalle del jugador:** bloque **Satisfacción** con la barra y sus **expectativas**, cada una con `Icons.check_circle` (cumplida) o `Icons.cancel` (incumplida), nunca caracteres ✓/✗ ("Ser titular", "Cobrar lo que vale", "Jugar en 1ª División", "Equipo de prestigio ≥ 80", "Tener equipo"). Bloque **Contrato de representación** con la comisión mostrada como «5 %» (en el código siempre es una fracción, `0.05`) y semanas restantes.
  - Botón **Hablar con él** (si quiere hablar): opciones **Prometer mejorar** (+10 ya, −20 si en 13 semanas no cumples), **Pagar un bono** (5 % de su valor, +15, con confirmación) o **Ignorar** (−10).
  - Botón **Renegociar contrato** (si quedan ≤ 8 semanas): pantalla con dos controles (comisión 3–10 %, duración 26/52/78/104 semanas) y vista previa de si aceptará.
- **Resumen:** tarjeta **Salud de la agencia**: satisfacción media y tus 3 representados más descontentos.
- **Noticias:** renuncias, robos, renovaciones de contrato de representación.

## 3B.2 Reglas y fórmulas (constantes en `lib/logica/satisfaccion.dart`)

**Expectativas:** al reclutar (y al migrar partidas viejas) cada jugador recibe 1–2 según su situación, máximo 2:

1. Sin equipo → `tenerEquipo`.
2. Con equipo y suplente → `serTitular`.
3. Equipo de 2ª División y edad ≤ 24 → `primeraDivision`.
4. Habilidad ≥ 65 → `cobrarLoQueVale` (salario ≥ 90 % del salario de mercado: `porcentajeSalarioAceptable = 0.90`).
5. Equipo de 1ª con prestigio ≥ 80 → `equipoPrestigioAlto` (suele nacer cumplida).
6. Si aún le falta una y tiene habilidad ≥ 55 → `cobrarLoQueVale`; si no, y tiene equipo → `serTitular`.

**Actualización semanal:**

```
delta = cumplidas todas ? +0.5 : −1.5 × incumplidas
delta += quiereHablar ? −2 : 0
satisfaccion = clamp(satisfaccion + delta, 0, 100)
```

Constantes: `deltaSatisfaccionSemanalCumplida = 0.5`, `deltaSatisfaccionSemanalIncumplida = 1.5`, `penalizacionSemanalQuiereHablar = 2`. Con 2 expectativas incumplidas: −3/semana → de 70 a 35 en ~12 semanas.

**Eventos que la mueven:**

- Traspaso aceptado a equipo con prestigio < anterior − 10: −15 (`umbralDiferenciaPrestigio = 10`, `efectoTraspasoPeorEquipo = -15`); > anterior + 10: +10 (`efectoTraspasoMejorEquipo = 10`).
- Renovación con salario menor al actual: −10; mayor: +10 (`efectoRenovacionSatisfaccion = 10`).
- Suplente todo un split: −8 (junto al castigo de moral existente; `efectoSuplenteSplitSatisfaccion = 8`).
- Ganar un título: +10; el Mundial: +15 (`efectoTituloSatisfaccion = 10`, `efectoMundialSatisfaccion = 15`).

**Querer hablar y promesas:**

- `satisfaccionAlerta = 45` → `quiereHablar = true` (aviso en Mi agencia y banner en el detalle).
- Opciones: **prometer** (+`promesaSatisfaccion = 10`, `semanasPromesaPendiente = 13`; al cumplirse el plazo, si las expectativas que motivaron la promesa siguen incumplidas → −`castigoPromesaIncumplida = 20`; si se cumplieron → +5); **bono** (`porcentajeBonoApaciguar = 0.05` del valor de mercado, +15, con confirmación); **ignorar** (−10).
- Al prometer, `quiereHablar` queda en false hasta que pase el plazo o vuelva a bajar de 45.

**Marcharse:**

- `satisfaccionCritica = 25` → cada semana `probRenunciaSemanal = 0.25` de irse. Si hay un rival que lo acepte, se va con él (reglas de 3A); si no, queda sin agente. Noticia en ambos casos.

**Contrato de representación:**

- **Unidad de la comisión:** en el código siempre es una fracción (`0.05`, rango `0.03`–`0.10`); en la interfaz siempre se muestra como porcentaje (`5 %`, `3 %–10 %`). Nunca se guardan porcentajes enteros.
- Al reclutar: `semanasContratoRepresentacion = 52` y `comisionSalarioContrato = 0.05`.
- La comisión semanal pasa a usar **la del contrato** (antes el 5 % fijo `comisionSalario`). El 5 % queda como valor inicial, así las partidas viejas no cambian.
- Renegociación (≤ `umbralSemanasRenovacionRepresentacion = 8`): comisión entre `comisionRepresentacionMin = 0.03` y `comisionRepresentacionMax = 0.10`; duración mínima `duracionMinimaRenovacion = 26`.
- El jugador acepta si `comisionOfrecida ≤ comisionMaximaAceptable(satisfaccion, duracionSemanas)`:
  ```
  base = clamp(0.05 + (satisfaccion − 60) / 2000, 0.03, 0.08)
  comisionMaximaAceptable = base − (duracionSemanas ≥ 78 ? 0.01 : 0)
  ```
  Los contratos de **78–104 semanas** exigen **1 punto porcentual menos** de comisión (0,01 en fracción). Si el resultado queda por debajo de `comisionRepresentacionMin = 0.03`, el jugador no acepta ninguna comisión válida para esa duración.
- Si el contrato expira sin renovar → queda sin agente (noticia). "Dejar de representar" sigue disponible y rompe el contrato.

## 3B.3 Campos nuevos y guardado

| Campo en `Jugador` | Tipo | Valor por defecto en `fromJson` |
|---|---|---|
| `satisfaccion` | `int` | `70` (ya creado en 3A) |
| `expectativas` | `List<String>` | `[]` |
| `quiereHablar` | `bool` | `false` |
| `semanasPromesaPendiente` | `int` | `0` |
| `semanasContratoRepresentacion` | `int` | `52` |
| `comisionSalarioContrato` | `double` | `0.05` |

- `versionFormato` sube a **11**. Migración v<11: generar expectativas a mis representados y contrato 52 semanas / 5 % si no tienen.

## 3B.4 Pruebas a agregar (`test/satisfaccion_test.dart`)

- Delta semanal: cumplir sube, incumplir baja, acotado 0–100.
- `quiereHablar` a 45; promesa (+10 ahora, castigo −20 a las 13 semanas si no cumplió, +5 si cumplió); bono paga y sube; ignorar baja.
- Renuncia a < 25 con semilla fija: se va con un rival o queda sin agente; queda enfriamiento.
- La comisión semanal usa la del contrato y no el 5 % fijo.
- Renegociación: acepta si la comisión ≤ `comisionMaximaAceptable`; los contratos de 78–104 semanas exigen 0,01 menos; rechaza fuera de rango; expiración sin renovar deja sin agente.
- Traspaso a equipo peor/mejor y renovaciones con más/menos salario mueven la satisfacción.
- Una partida v10 (con rivales, sin 3B) carga con expectativas generadas y defaults.
- Métricas para el robot: pérdidas por temporada por insatisfacción/robo.

## 3B.5 Criterios de balance (robot e informe)

- El robot pierde **≤ 1–2 representados por temporada** por insatisfacción o robo.
- Satisfacción media de su cartera entre **55 y 85** al final de la T3.
- Comisión media de sus contratos entre **0,04 y 0,06** (4 %–6 % en la interfaz).
- Sin promesas rotas acumuladas: ≤ 2 castigos por promesa incumplida en la partida.
- El robot responde los "quiere hablar" (política: prometer si tiene dinero, si no ignorar).

---

# PARTE 3C — OJEADORES

## 3C.1 Qué ve el jugador

- **Nueva pantalla "Ojeadores"** (botón en Mi agencia): lista de tus ojeadores con nombre, videojuego, región, nivel (`Icons.star` repetido 1–5, nunca estrellas como texto), salario semanal y semanas que llevan. Botones:
  - **Contratar ojeador**: elegir videojuego → región (de las existentes en `regiones.json`) → nivel; muestra el salario semanal y pide confirmación.
  - **Despedir** (confirmación). Máximo `maxOjeadores = 6`; se indica cuántos cupos quedan.
- **Mercado:** el potencial ya no es un número fijo: se muestra como rango estimado, ej. "72–88", con un ícono de lupa y una nota de precisión ("Ojeador nivel 3 · 6 semanas" o "Sin ojeador"). Cuando el semiancho llega a 0 se muestra el número exacto.
- **Sección "Talentos descubiertos"** en el Mercado: jóvenes con potencial muy alto que solo aparecen si tienes un ojeador en su región (ver talentos ocultos).
- **Detalle del jugador:** rango de potencial y estado de observación. Se recalcula cada semana solo para estrecharse; si deja de estar cubierto, conserva lo ya descubierto.

## 3C.2 Reglas y fórmulas (constantes en `lib/logica/ojeadores.dart`)

**Modelo `Ojeador`:** id, nombre (aleatorio), `juego`, `region`, `nivel` (1–5).

**Costos:** `costoOjeadorPorNivel = [0, 100, 200, 350, 550, 800]` dólares **por semana**, cobrados en `avanzarSemana` junto a la oficina y registrados en gastos. El ajuste fino se hará en la sesión de balance.

**Potencial oculto (error fijo + semiancho que se cierra):**

- **Error fijo de por vida:** al crearse (jugador nuevo, reemplazo, joven o talento oculto), cada jugador recibe un `errorPotencial` entero uniforme en `[−errorPotencialMax, errorPotencialMax]`, con `errorPotencialMax = 15`. No se sortea cada semana, no cambia al guardar/cargar y no depende del ojeador.
- **Semiancho visible** (la notación del documento es siempre ±N, nunca el ancho total). `nivelMejor` es el nivel del mejor ojeador que cubre al jugador esta semana (0 si ninguno):
  ```
  semianchoVisible = max(0, semianchoPotencialSinOjeador − reduccionSemianchoPorNivel × nivelMejor − floor(semanasObservado / 2))
  ```
  con `semianchoPotencialSinOjeador = 15`, `reduccionSemianchoPorNivel = 2` y `reduccionSemianchoPorSemana = 0.5` (1 punto de semiancho cada 2 semanas).
- **Centro que converge al valor real:** con `t = semianchoVisible / semianchoPotencialSinOjeador`:
  ```
  potencialVisibleMin = clamp(round(potencial + (errorPotencial − 15) × t), habilidad, 99)
  potencialVisibleMax = clamp(round(potencial + (errorPotencial + 15) × t), habilidad, 99)
  ```
  En `t = 1` el rango inicial es `(potencial + errorPotencial) ± 15`; en `t = 0` es el potencial exacto. Siempre contiene al potencial real, nunca baja de la habilidad y solo se estrecha hacia el valor real.
- **Nunca se reabre:** al recalcular se conserva la intersección con el rango anterior (`min = max(minAnterior, nuevoMin)`, `max = min(maxAnterior, nuevoMax)`). Si despedís al ojeador o el jugador sale de su cobertura, mantiene lo ya descubierto.
- Ejemplos de semiancho: sin ojeador → ±15. Nivel 1 y 4 semanas → ±11. Nivel 3 y 8 semanas → ±5. Nivel 5 y 10 semanas → ±0 (exacto).
- `semanasObservado` sube 1 por semana (tope `semanasMaxObservacion = 20`) para los jugadores del juego+región que cubre un ojeador **y** cuyo semiancho aún no es 0. Solo se actualizan jugadores sin equipo, jóvenes y jugadores de equipos de esa región (no el mundo entero).
- Los **rivales (3A) no ven el número real**: usan el **mismo `errorPotencial` fijo** del jugador a través de `potencialEstimado = clamp(potencial + errorPotencial, habilidad, 99)`. No recalculan la niebla cada semana: es la misma que tienes tú sin ojeador (semiancho inicial ±15).

**Talentos ocultos:**

- Al empezar cada temporada se genera **1 joven oculto por región y videojuego** (`talentosOcultosPorRegion = 1`): edad 16–20, habilidad 25–40, potencial 70–99, `oculto = true`.
- Solo aparecen en el Mercado (sección "Talentos descubiertos") si tienes un ojeador en su región (`nivelMinimoVerOcultos = 1`).
- Los rivales tampoco los ven mientras estén ocultos. Si al terminar la temporada nadie los reclutó, se destapan (`oculto = false`) y pasan al mercado normal de jugadores sin equipo.

## 3C.3 Campos nuevos y guardado

| Modelo / Campo | Tipo | Valor por defecto en `fromJson` |
|---|---|---|
| Nuevo `lib/modelos/ojeador.dart` | — | `nivel` acotado 1–5 al cargar |
| `EstadoPartida.ojeadores` | `List<Ojeador>` | `[]` |
| `Jugador.semanasObservado` | `int` | `0` |
| `Jugador.errorPotencial` | `int` | `0` (partidas viejas; la migración v<12 asigna uno aleatorio a cada jugador para que los rivales tampoco vean el potencial real) |
| `Jugador.potencialVisibleMin` | `int?` | `null` → se muestra el potencial exacto (partidas viejas conservan lo que ya sabían) |
| `Jugador.potencialVisibleMax` | `int?` | `null` (ídem) |
| `Jugador.oculto` | `bool` | `false` |

- `versionFormato` sube a **12**. Los jugadores nuevos (jóvenes, reemplazos, jugadores sin equipo) nacen con `errorPotencial` aleatorio y rango inicial `potencialEstimado ± 15`; las partidas viejas conservan el rango nulo = exacto para ti, pero la migración asigna un `errorPotencial` fijo a cada jugador para que los rivales compartan la misma niebla.

## 3C.4 Pruebas a agregar (`test/ojeadores_test.dart`)

- Fórmula del semiancho para niveles 1–5 y semanas 0–20; exacto en nivel alto.
- `errorPotencial` fijo: dos semanas consecutivas sin cambiar nivel ni semanas producen el mismo centro; no hay sorteo semanal.
- El rango se estrecha de forma monótona y converge al potencial real; nunca se reabre al despedir al ojeador.
- Cobertura por juego+región: `semanasObservado` solo sube para cubiertos, con tope 20.
- Los rangos siempre están dentro de [habilidad, 99] y contienen al potencial real.
- Ocultos invisibles sin ojeador en su región y visibles con él; se destapan al terminar la temporada.
- Contratar respeta el dinero y `maxOjeadores`; despedir deja de cobrar; el salario semanal aparece en gastos.
- Los rivales usan el mismo `errorPotencial` fijo: con semilla fija, no fichan sistemáticamente al mejor joven real.
- Partida v11 carga con ojeadores vacíos, rangos nulos (sigue viendo exacto) y `errorPotencial` asignado para los rivales.

## 3C.5 Criterios de balance (robot e informe)

- El robot contrata **2 ojeadores de nivel 2** (política fija) cuando el dinero lo permite.
- El **semiancho** medio del potencial de sus fichajes **baja de la T1 a la T3** (medido en el informe).
- Gasto total en ojeadores ≤ **15 %** de los ingresos del robot en la T3.
- **Los rivales no se quedan con todos los mejores jóvenes:** al final de la T3, ≤ **40 %** de los 20 potenciales reales más altos están con rivales.

---

# PARTE 3D — STAFF DE LA AGENCIA

## 3D.1 Qué ve el jugador

- **Nueva pantalla "Staff"** (botón en Mi agencia): 3 puestos fijos con su estado:
  - **Abogado** — "Los equipos aceptan pedir hasta X % más del valor" (+2 % por nivel) y "menos probabilidad de que retiren la oferta al pedir más".
  - **Relaciones públicas** — "Reduce en X % el daño de los eventos negativos".
  - **Preparador** — "Tus jugadores progresan X % más rápido".
- Cada puesto muestra: vacante (botón **Contratar**) o nivel actual con salario semanal (botones **Mejorar** y **Despedir**, con confirmación).
- **Mi agencia:** línea con el gasto semanal total (oficina + ojeadores + staff + academia).
- Niveles 1–5; 1 miembro por puesto (`maxStaffPorRol = 1`).

## 3D.2 Reglas y fórmulas (constantes en `lib/logica/staff.dart`)

**Salarios semanales:** `costoStaffPorNivel = [0, 80, 160, 280, 450, 650]`, cobrados en `avanzarSemana` y registrados en gastos. El ajuste fino se hará en la sesión de balance. Mejorar paga `(salarioNuevo − salarioViejo) × 13` (`semanasCostoMejoraStaff = 13`) con confirmación; despedir es gratis.

**Abogado:**

- Margen extra de aceptación en `calcularRespuesta` (ya existe el parámetro `margenExtraAceptacion`): `margenAbogadoPorNivel × nivel` con `margenAbogadoPorNivel = 0.02` (máximo +0,10 en nivel 5). El límite de aceptación pasa de 1,05 a `1.05 + margen`.
- Al "pedir más", la probabilidad de retirada se multiplica por `1 − reduccionRetiradaAbogado × nivel`, con `reduccionRetiradaAbogado = 0.05` (nivel 5: −25 % de retiradas).

**Relaciones públicas:**

- Los eventos negativos que quitan reputación, moral o valor reducen su pérdida multiplicando por `1 − reduccionDanioRP × nivel`, con `reduccionDanioRP = 0.15` (nivel 5: −75 %). Se redondea hacia arriba y nunca deja la pérdida por debajo de 1 (si había pérdida). No afecta a costos de dinero (auditorías, asesor de imagen).

**Preparador:**

- La probabilidad de progresión semanal de **mis representados** se multiplica por `1 + bonusProgresionPreparador × nivel`, con `bonusProgresionPreparador = 0.08` (tope ×1,4). No se aplica dentro de la academia (3E), que ya entrena con su propio bonus.

**Efectos combinados:** abogado y RP pueden convivir sin conflicto; el preparador multiplica, no suma, sobre la tabla de `progresion.dart`.

## 3D.3 Campos nuevos y guardado

| Modelo / Campo | Tipo | Valor por defecto en `fromJson` |
|---|---|---|
| Nuevo `lib/modelos/staff.dart` (`MiembroStaff`) | id, rol (`String`, enum `RolStaff`), nombre, nivel | `rol` desconocido cae a `abogado`; `nivel` acotado 1–5 |
| `EstadoPartida.staff` | `List<MiembroStaff>` | `[]` |

- `versionFormato` sube a **13**. Partidas viejas: staff vacío = sin efectos (comportamiento idéntico al actual).

## 3D.4 Pruebas a agregar (`test/staff_test.dart`)

- Margen del abogado en `calcularRespuesta` (niveles 0–5) y retirada reducida al pedir más.
- RP reduce pérdidas de eventos negativos (reputación/moral/valor) según nivel; nunca a 0 si había pérdida.
- Preparador multiplica la progresión solo de mis jugadores y respeta el tope ×1,4.
- Salarios semanales cobrados; máximo 1 por rol; mejorar cobra la diferencia.
- Partida v12 carga con staff vacío.

## 3D.5 Criterios de balance (robot e informe)

- El robot contrata **abogado nivel 2 en la T2** y **RP nivel 2 en la T3** (política fija, solo si el dinero alcanza).
- Gasto total en staff ≤ **20 %** de los ingresos del robot en la T3 y sin quiebra.
- Con el abogado, el robot vende **al menos lo mismo que sin él** (el margen extra no rompe la negociación: máximo 1,15 del valor).

---

# PARTE 3E — ACADEMIA

## 3E.1 Qué ve el jugador

- **Nueva pantalla "Academia"** (botón en Mi agencia):
  - Lista de tus jóvenes (edad, habilidad, rango de potencial, semanas entrenando, costo semanal $150).
  - Botón **Reclutar joven**: lista de candidatos de 15–17 años (2 por videojuego, nuevos cada temporada) con su rango de potencial y costo de $500; respeta la capacidad (4 plazas).
  - Botón **Colocar en un equipo** (si cumple los requisitos): lista de equipos de 2ª División del mismo videojuego que pueden pagarlo. El equipo paga su valor de mercado y tú cobras el **100 % como derechos de formación** (no hay club vendedor).
  - Botón **Soltar** (confirmación).
- **Resumen:** aviso "Tienes jóvenes listos para colocar" cuando corresponde.
- **Noticias:** fichaje de un joven de tu academia y su traspaso a un equipo.

## 3E.2 Reglas y fórmulas (constantes en `lib/logica/academia.dart`)

**Candidatos:**

- Al empezar cada temporada se generan `jovenesAcademiaPorTemporada = 8` (2 por videojuego): edad 15–17 (`edadAcademiaMin = 15`, `edadAcademiaMax = 17`), habilidad 25–45, potencial 60–95, `candidatoAcademia = true`.
- Solo se ven en la pantalla Academia; **no** aparecen en el Mercado, **no** los fichan los rivales y el mantenimiento (tope de 300 jugadores sin equipo) **no** los borra. Los que nadie reclutó se destapan como jugadores sin equipo normales al terminar la temporada (`candidatoAcademia = false`).

**Reclutar y mantener:**

- Costo de fichaje `costoFichajeAcademia = 500` (una vez, con confirmación). Capacidad `capacidadAcademia = 4`.
- Al entrar: `enAcademia = true`, `representadoPorMi = true` y `agenteId = 'yo'`. El contrato de representación (3B) **no corre** mientras esté en la academia y no puede ser robado.
- Mantenimiento: `costoSemanalAcademiaPorJoven = 150` por joven, cobrado en `avanzarSemana`.
- Entrenamiento: progresión semanal normal con `bonusProgresionAcademia = 1.5` multiplicando la probabilidad. El preparador (3D) no se apila aquí.

**Colocar en un equipo:**

- Requisitos: `edad ≥ edadMinimaColocacion = 17`, `semanasEnAcademia ≥ semanasEntrenamientoMinimo = 4` y `habilidad ≥ habilidadMinimaColocar = 45`. Un joven de 15–16 años no se puede colocar aunque cumpla lo demás.
- Destino: equipos de **2ª División** del mismo videojuego (cualquier región) con `presupuesto ≥ valorMercado`. Si ninguno puede pagar, no se puede colocar esta semana (mensaje).
- **Flujo del dinero:** al confirmar, el equipo paga el **valor de mercado completo** del joven y la agencia recibe el **100 %** como **derechos de formación** (`porcentajeDerechosFormacion = 1.0`). **No hay club vendedor**: el joven nunca perteneció a un equipo, así que no se reparte dinero con ningún club. El joven queda con contrato de 52 semanas con su nuevo equipo, `enAcademia = false`, contrato de representación de 52 semanas y noticia.
- En `INFORME_BALANCE.md`, estos ingresos se registran en la fila **Academia** de la tabla de ingresos del robot (no como comisión de traspaso).

**Salida por edad o soltar:**

- Al cumplir `edadSalidaAcademia = 18` sin haber sido colocado: cada semana `probSalidaAcademiaSemanal = 0.20` de irse por su cuenta (queda como agente libre: sin agente y sin equipo; noticia; pierdes lo invertido).
- **Soltar:** el joven queda como agente libre (sin agente y sin equipo; confirmación).

## 3E.3 Campos nuevos y guardado

| Campo en `Jugador` | Tipo | Valor por defecto en `fromJson` |
|---|---|---|
| `enAcademia` | `bool` | `false` |
| `semanasEnAcademia` | `int` | `0` |
| `candidatoAcademia` | `bool` | `false` |

- `versionFormato` sube a **14**. Partidas viejas: todo en false; los candidatos se generan en la próxima temporada.
- `mantenimiento.dart` se actualiza para no borrar académicos ni candidatos al recortar jugadores sin equipo.

## 3E.4 Pruebas a agregar (`test/academia_test.dart`)

- Generación de candidatos: 8 por temporada, edades 15–17, 2 por videojuego.
- Reclutar respeta capacidad y cobra $500; mantenimiento semanal de $150 por joven.
- Progresión con bonus: con semilla fija, un joven en academia sube más que uno sin equipo equivalente.
- Colocación: solo 2ª División, edad ≥ 17, el equipo paga el valor de mercado completo, cobro el 100 % como derechos de formación, no hay club vendedor y el joven sale de la academia con contrato 52 semanas.
- Un joven de 16 años no se puede colocar aunque tenga habilidad ≥ 45 y 4 semanas de academia.
- El ingreso de la colocación se contabiliza en la fila **Academia** de la tabla de ingresos del robot.
- A los 18 sin colocar puede irse (semilla fija); soltar funciona.
- Rivales y mantenimiento no tocan candidatos ni académicos.
- Partida v13 carga con los tres campos en false.

## 3E.5 Criterios de balance (robot e informe)

- El robot recluta **2 jóvenes en la T1** y coloca **al menos 1 antes de terminar la T2**.
- El saldo neto de la academia (derechos de formación − costos) al final de la T3 es **≥ $0** o la pérdida no supera **$30.000**.
- La habilidad media al colocar queda en **45–65** (nada de niños de 80+ saliendo de la academia).
- **El 100 % de los jóvenes de la academia los coloca el jugador o se van como agentes libres**: los rivales nunca tocan la academia (medido en el informe).

---

# RIESGOS

## R1 — Rendimiento con miles de jugadores

- Hoy hay ~2.800 jugadores y la semana tarda **~85 ms** (media global del último `INFORME_BALANCE.md`; T10/T1 ≤ 1,5×). La Fase 3 suma: satisfacción semanal, rivales, ojeadores y academia. Mitigaciones obligatorias:
  - Mantener **un solo recorrido por jugador y semana** (satisfacción + progresión + contrato + enfriamiento juntos, como en la corrección A3).
  - Rivales: máximo **1 acción por rival y semana** y solo sobre listas filtradas (jugadores sin agente que acepten, representados míos insatisfechos).
  - Ojeadores: actualizar solo jugadores de su región cuyo semiancho no sea 0 (tope 20 semanas de observación).
  - Listas nuevas con `ListView.builder` y caché de filtros como en `PestanaMercado` (I10).
  - Medir en `INFORME_BALANCE.md`: tiempo T10/T1 ≤ 1,5× y el tamaño del guardado (hoy ~3,6 MB; los rivales + expectativas + staff añaden datos, se espera ≤ +10 %).

## R2 — Compatibilidad de partidas viejas

- Cinco subidas de versión (10 a 14). Reglas para no romper nada:
  - Todo campo nuevo tiene **valor por defecto en `fromJson`** que reproduce el comportamiento anterior (comisión 5 %, potencial exacto, sin staff ni academia).
  - **"Lo que ya sabías no se oculta":** las partidas viejas conservan el potencial exacto (rango nulo) y no reciben castigos retroactivos. El `errorPotencial` que se asigna en la migración solo lo usan los rivales para su niebla; no cambia el rango visible del jugador.
  - Las migraciones al cargar son aditivas: generar rivales (3A), expectativas (3B) y candidatos de academia (3E) sin alterar el RNG de partidas en curso más de lo necesario.
  - `versionMinimaCompatible` sigue en **3**; añadir a `test/guardado_test.dart` la carga de v9–v13 en cada parte.
  - El fixture de `golden_test.dart` cambia con cada parte: **regenerar capturas** al final de cada sesión.

## R3 — Balance de la reputación ahora que hay competencia

- **Riesgo de bloqueo inicial:** con rivales de reputación 20–90, las disputas podrían impedir fichar. Mitigación: solo disputan rivales con rep ≤ mía + 25 y la disputa se gana por atractivo (la reputación del jugador sube con traspasos, así que recupera terreno).
- **Riesgo de espiral de pérdidas:** perder representados reduce ingresos → menos traspasos → menos reputación. Mitigaciones: enfriamiento de 26 semanas tras cada cambio de agente, umbrales de satisfacción claros (45 aviso, 25 salida) y criterio duro del robot: **≤ 1–2 pérdidas por temporada**.
- **Riesgo de que los rivales acaparen el talento joven:** mitigado con la niebla de potencial (error fijo y semiancho inicial ±15) que los rivales comparten con el jugador sin ojeador, y con la academia (3E) como cantera protegida. Criterio: ≤ 40 % de los 20 mejores potenciales con rivales al final de la T3.
- **Riesgo de reputación estancada:** si con la competencia el robot no llega a 30–45 al final de la T3, palancas en orden: bajar `probDisputaRivalBase`, dar +1 de reputación por robo frustrado, o subir `reputacionTraspasoNormal`. Máximo 3 rondas de ajuste anotadas en el informe (regla de la Fase 2.5).
- **Riesgo de Agente del Año imposible:** se compara por puntos totales (títulos + premios + MVPs de los clientes), no por número de clientes, para que una cartera pequeña pero ganadora pueda vencer a una grande.

## R4 — Interacciones entre sistemas nuevos

- La satisfacción penaliza cosas que no controlas (suplencias, ventas de la IA ajenas). Los castigos fuertes solo se aplican tras umbrales de semanas (suplente todo un split, expectativa incumplida durante semanas), para que se sienta justo y no aleatorio.
- El robo (3A), la satisfacción (3B) y el contrato (3B) comparten el mismo campo de enfriamiento (`semanasEnfriamientoAgente`) para no pelearse entre sí. La espera de 13 semanas por un "Convencer" fallido es un campo aparte (`semanasEsperaConvencer`) y no bloquea el resto de acciones del jugador.
- El preparador (3D) no se apila con el bonus de la academia (3E) para evitar progresión doble.
- La RP (3D) modifica pérdidas de eventos (2E): aplicar el multiplicador en el punto único donde se resuelven, y probar que un evento resuelto dos veces no descuenta dos veces (regla de idempotencia existente).

---

## LISTA DE PRUEBAS MANUALES DE LA FASE 3

### 3A
- [ ] La sección Agentes dentro de Mi agencia muestra el ranking conmigo incluido y los rivales con perfil y cartera; la barra inferior sigue teniendo 5 pestañas.
- [ ] Al reclutar un jugador sin agente, a veces aparece la disputa y puede ganarla el rival.
- [ ] Un jugador de un rival muestra "Representado por..." y el botón Convencerlo funciona o falla con mensaje.
- [ ] Tras fallar un Convencer no puedo reintentar hasta 13 semanas; si el rival gana una disputa, el jugador queda 26 semanas sin cambiar de agente.
- [ ] Aparecen noticias de fichajes y robos de rivales.
- [ ] La ceremonia del Agente del Año muestra el podio con rivales.

### 3B
- [ ] Cada representado muestra satisfacción y expectativas con `Icons.check_circle` / `Icons.cancel` (no texto ✓/✗).
- [ ] Un jugador descontento pide hablar; prometer, pagar bono e ignorar tienen efectos distintos.
- [ ] Puedo renegociar comisión y duración; una comisión alta es rechazada, y los contratos de 78–104 semanas exigen 1 punto menos.
- [ ] Un jugador con satisfacción < 25 puede irse con otro agente.
- [ ] La comisión semanal usa la del contrato y se muestra como «5 %» en la interfaz.

### 3C
- [ ] El potencial se muestra como rango con semiancho ±N y se va cerrando con el ojeador adecuado; nunca se reabre.
- [ ] Contratar un ojeador cobra salario semanal; despedirlo deja de cobrar.
- [ ] Los talentos ocultos solo aparecen con ojeador en su región.

### 3D
- [ ] El abogado sube el margen de aceptación visiblemente en la negociación.
- [ ] Con RP, un evento negativo quita menos reputación.
- [ ] Con preparador, mis jóvenes progresan más rápido.

### 3E
- [ ] Puedo reclutar jóvenes de 15–17 hasta llenar las 4 plazas.
- [ ] Un joven de 17 años, entrenado y con habilidad ≥ 45, se puede colocar en un equipo de 2ª División: el equipo paga su valor completo y cobro el 100 % como derechos de formación.
- [ ] Un joven de 16 años no se puede colocar aunque cumpla lo demás.
- [ ] El ingreso de una colocación aparece como **Academia** en la tabla de ingresos del robot.
- [ ] Un joven que cumple 18 sin colocar puede irse.
