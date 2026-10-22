# PLAN PARTE 2E — EVENTOS ALEATORIOS

> Documento de trabajo para OpenCode. Basado en `PLAN.md` (sección 0),
> `PLAN_FASE2.md` (Parte 2E) y `PROGRESO.md`.
> Se implementa **SOLO la Parte 2E**. Nada de la Fase 3.
> Las reglas de la sección 0 de `PLAN.md` siguen vigentes: comentarios en
> español, mínimos paquetes, confirmación antes de gastar, `flutter analyze`,
> `flutter test` y prueba en Linux.

---

## 1. OBJETIVO

Que cada semana puedan pasar cosas que afecten a mis jugadores y a mi agencia:

- **8 % semanal por cada jugador representado** de tener un evento.
- **15 % semanal de un evento de agencia** (además de los eventos de jugadores).
- **Máximo 3 eventos nuevos por semana** para no saturar.
- Ventana emergente después de avanzar la semana, mostrando los eventos uno
  tras otro.
- Eventos informativos (botón **Entendido**) y eventos con **dos opciones**.
- Todo gasto muestra su costo y pide confirmación.
- **Nunca** se cobra más del **30 % del dinero actual** del agente.
- Cada evento queda registrado como **noticia**.
- Eventos positivos, negativos, neutrales, de agencia y del mundo.
- Opción **Frecuencia de eventos** en Ajustes: Baja (×0,5), Normal (×1), Alta (×2).

---

## 2. DECISIONES DE DISEÑO Y COMPATIBILIDAD

1. **Guardado compatible:** `versionFormato` sube de **5 a 6**.
   `versionMinimaCompatible` se mantiene en **3**. Las partidas v3, v4 y v5 se
   cargan con los campos nuevos vacíos/por defecto y se vuelven a guardar como
   v6. Las v1 y v2 siguen siendo incompatibles.
2. **Estado nuevo tolerante:** todos los campos nuevos tendrán valor por
   defecto en `fromJson`, igual que se hizo en 2C y 2D.
3. **Eventos pendientes serializables:** una partida se puede cerrar con una
   ventana de evento abierta y, al cargarla, el evento vuelve a aparecer.
4. **Los eventos no se aplican al generarse, sino al resolverse.** Así una
   decisión no cambia el mundo hasta que el usuario elige. Excepción: los
   eventos del mundo (2E.6) son solo noticia, se aplican al generarse y no
   abren ventana.
5. **Un jugador representado recibe como máximo 1 evento por semana.** La
   agencia recibe como máximo 1 evento de agencia por semana.
6. **Prioridad de generación:** primero eventos de jugadores, después el de
   agencia y por último el del mundo, siempre respetando el máximo de 3.
7. **Costos seguros:** el costo base de un evento se guarda, pero al mostrarlo
   y al cobrarlo se limita con `limitarCostoEvento(costoBase, dineroActual)`:
   `min(costoBase, 30 % del dinero actual)`, nunca negativo.
8. **Eventos con gasto:** el diálogo muestra el costo ya limitado y, al pulsar
   la opción de pago, se abre un **diálogo de confirmación**. Si el usuario
   cancela, el evento sigue pendiente y no se cobra nada.
9. **Fuga de información (2E.5):** solo puede generarse dentro de una ventana
   de fichajes y si tengo un representado con equipo. Fuera de ventana se
   evita para no romper la regla de la Parte 2D. La oferta se crea con el
   modelo `Oferta` existente y 2 semanas para responder.
10. **Inversor (2E.5):** durante 26 semanas se descuenta el **10 % de todas
    las comisiones** (salarios, traspasos y renovaciones). No se puede tener
    más de un inversor activo a la vez.
11. **Contacto en un equipo grande (2E.5):** durante 4 semanas, los equipos de
    prestigio ≥ 85 aceptan ofertas con **+0,10** de margen (es decir, el
    límite de aceptación pasa de 1,05 a 1,15). No se acumula.
12. **Jugadores inactivos:** nuevo campo `semanasInactivo` en `Jugador` para
    lesiones y descansos. Mientras sea > 0, el jugador **no juega** ni cuenta
    para el poder del equipo; el equipo usa un suplente o el siguiente
    disponible. Se muestra en la ficha, la tarjeta y la plantilla.
13. **Cambio de videojuego:** si el jugador acepta, cambia de juego y de rol
    (se conserva la posición dentro de la lista de roles del nuevo juego). Si
    tenía equipo, queda libre para evitar plantillas incoherentes y su club
    repone el hueco con el sistema de 2D.
14. **Problemas con el equipo:** si sale el 25 %, el jugador queda libre
    (equipoId = null, contrato = 0, sin suplencia) y su club repone el titular.
15. **Sin paquetes nuevos.** Todo con Flutter, `dart:math` y lo ya existente.

---

## 3. MODELOS Y ESTADO

### 3.1 `lib/modelos/jugador.dart` (modificar)

- Nuevo campo `int semanasInactivo` (por defecto `0`).
- Getter `bool get estaInactivo => semanasInactivo > 0;`.
- `toJson()` lo incluye.
- `fromJson()` lo lee de forma tolerante:
  `(json['semanasInactivo'] as num?)?.toInt() ?? 0`.

### 3.2 `lib/modelos/evento.dart` (nuevo)

- `enum FrecuenciaEventos { baja, normal, alta }`:
  - `nombre` visible: "Baja", "Normal", "Alta".
  - `multiplicador`: 0,5 / 1 / 2.
  - `static FrecuenciaEventos porNombre(String? nombre)` con `normal` por
    defecto.
- `class EventoPendiente`:
  - `id` (único, ej: `ev_1_23_001`).
  - `definicionId` (id del evento en el catálogo).
  - `jugadorId` (`String?`; null en eventos de agencia).
  - `titulo` y `descripcion` (texto ya interpolado con `{nick}`).
  - `esDecision` (bool); si es false, solo tiene opción "Entendido".
  - `opcionA`, `opcionB` (`String?`): textos de las opciones.
  - `costoBaseA`, `costoBaseB` (int, 0 si no cuesta).
  - `temporada`, `semana`.
  - `toJson()` / `fromJson()` tolerantes.
- El catálogo de definiciones **no se guarda**: vive en `eventos.dart`. Si al
  cargar aparece un `definicionId` desconocido, el motor descarta el evento con
  una noticia informativa en vez de romper la partida.

### 3.3 `lib/modelos/estado_partida.dart` (modificar)

- `versionFormato = 6`; `versionMinimaCompatible = 3`.
- Nuevos campos:
  - `List<EventoPendiente> eventosPendientes` (default `[]`).
  - `String frecuenciaEventos` (default `'normal'`; se lee con
    `FrecuenciaEventos.porNombre`).
  - `int semanasInversor` (default `0`).
  - `int semanasContactoGrande` (default `0`).
- `toJson()` los incluye; `fromJson()` los lee con valores por defecto.

---

## 4. LÓGICA: `lib/logica/eventos.dart` (nuevo)

### 4.1 Constantes de balance (al inicio del archivo)

- Probabilidades semanales: jugador `0.08`, agencia `0.15`, mundo `0.10`.
- Máximo de eventos nuevos por semana: `3`.
- Máximo de eventos de agencia por semana: `1`.
- Máximo de eventos del mundo por semana: `1`.
- Porcentaje máximo del dinero que puede costar un evento: `0.30`.
- Inversor: 26 semanas y 10 % de comisiones.
- Contacto grande: 4 semanas y margen de aceptación `0.10`.
- Duraciones de lesión: tendinitis 2–6 semanas; exhibición 1–3 semanas;
  descanso por burnout 3 semanas.
- Pesos relativos de cada evento (ver 4.3).

### 4.2 Estructuras internas

- `enum AmbitoEvento { jugador, agencia, mundo }`.
- `class ContextoEventos`: estado, índices de jugadores/equipos, `Random`,
  generador de ids nuevos y helper para reponer titulares.
- `class DefinicionEvento`:
  - `id`, `titulo`, `descripcion` (con `{nick}`), `ambito`, `peso`.
  - `condicion` (función que recibe contexto y jugador opcional).
  - `opciones`: 1 opción informativa o 2 opciones de decisión.
  - `tipoNoticia` (evento, progreso, alerta o dinero).
- `class OpcionEvento`: texto, costo base (0 si no cuesta) y efecto.

### 4.3 Catálogo y pesos iniciales

**Jugadores positivos**

| id | Condición | Efecto | Peso |
|---|---|---|---|
| `despertar_talento` | edad ≤ 21 y activo | potencial +3 a +8 (máx. 99) | 8 |
| `partida_perfecta` | tiene equipo y activo | habilidad +2, moral +10, valor ×1,10 | 10 |
| `mentor_veterano` | edad ≤ 23, activo y dinero > 0 | **Decisión:** pagar 5 % del valor → habilidad +3 y potencial +2 / rechazar | 8 |
| `bootcamp_corea` | tiene equipo y activo | habilidad +1 a +3 | 10 |
| `cambio_rol_exitoso` | activo | habilidad +2 | 8 |
| `streamer_estrella` | activo | moral +15; agente gana $5.000–$20.000 | 10 |
| `idolo_pais` | habilidad ≥ 75 y activo | valor ×1,08; reputación +1 | 8 |

**Jugadores negativos**

| id | Condición | Efecto | Peso |
|---|---|---|---|
| `tendinitis` | activo | 2–6 semanas sin jugar; habilidad −1 a −3 | 10 |
| `burnout` | activo y (moral < 50 o edad ≥ 26) | **Decisión:** descanso 3 semanas (moral +20) / seguir jugando (moral −15; 30 % de −3 habilidad) | 8 |
| `polemica_redes` | activo | **Decisión:** pagar asesor $10.000–$30.000 (sin efecto) / ignorar (moral −10, valor ×0,90, reputación −2) | 10 |
| `bajon_forma` | activo | habilidad −2 a −4 | 10 |
| `techo_alcanzado` | edad ≥ 22, activo y potencial > habilidad + 2 | potencial = habilidad + 2 | 8 |
| `problemas_equipo` | tiene equipo y activo | moral −20; 25 % de quedar libre y que el club reponga el titular | 10 |
| `conflicto_agente` | activo y moral < 40 | **Decisión:** bono $5.000–$15.000 (moral +20) / ignorar (40 % de dejar la agencia) | 6 |

**Jugadores neutrales / de decisión**

| id | Condición | Efecto | Peso |
|---|---|---|---|
| `oferta_otro_juego` | activo | **Decisión:** cambiar de videojuego (habilidad ×0,75, potencial +5, rol equivalente) / quedarse | 6 |
| `marca_perifericos` | activo | **Decisión:** aceptar (agente gana $10.000–$50.000, moral −5) / rechazar | 10 |
| `torneo_exhibicion` | activo | **Decisión:** participar (moral +10, 20 % de lesión leve 1–3 semanas) / no participar | 10 |

**Agencia**

| id | Condición | Efecto | Peso |
|---|---|---|---|
| `prensa_favorable` | — | reputación +2 | 20 |
| `rumor_negativo` | — | reputación −2 | 20 |
| `inversor_interesado` | sin inversor activo | **Decisión:** recibir $25.000–$100.000 a cambio de 10 % de comisiones durante 26 semanas / rechazar | 10 |
| `auditoria_fiscal` | — | pagar $2.000–$10.000 (informativo, con aviso y confirmación) | 12 |
| `contacto_equipo_grande` | sin contacto activo | 4 semanas con +0,10 de margen en equipos de prestigio ≥ 85 | 10 |
| `fuga_informacion` | en ventana de fichajes y con un representado con equipo | oferta de traspaso inmediata de un rival por ese jugador | 10 |

**Mundo (solo noticia, sin ventana)**

| id | Efecto | Peso |
|---|---|---|
| `estrella_se_lesiona_o_retira` | jugador ajeno de habilidad ≥ 85: 50 % lesión 2–8 semanas / 50 % retirada (se repone su hueco) | 30 |
| `cambio_entrenador` | equipo aleatorio: moral de sus jugadores ±10 | 30 |
| `organizacion_nuevo_juego` | noticia de que una organización entra a otro videojuego (sin cambios estructurales) | 20 |
| `record_audiencia` | noticia de récord de audiencia | 20 |

### 4.4 Generación semanal

- `List<Noticia>` / `List<EventoPendiente> generarEventosSemana(...)`:
  1. Recorre mis jugadores representados en orden aleatorio.
  2. Por cada uno, con probabilidad `0,08 × multiplicador`, elige un evento
     elegible por peso relativo y lo convierte en `EventoPendiente`.
  3. Si aún hay hueco, con probabilidad `0,15 × multiplicador` genera **un**
     evento de agencia elegible.
  4. Si aún hay hueco, con probabilidad `0,10 × multiplicador` genera **un**
     evento del mundo; se aplica al momento y se devuelve su noticia.
  5. Corta al llegar a **3 eventos nuevos**.
- Un jugador inactivo no recibe eventos de jugador (salvo que se indique otra
  cosa en su condición).
- Se evita repetir una oferta de fuga ya pendiente para el mismo jugador.

### 4.5 Resolución

- `ResultadoEvento resolverEvento(...)` aplica la opción elegida y devuelve:
  texto de noticia, tipo de noticia y si hay que reconstruir índices.
- `0` = opción A (o "Entendido"); `1` = opción B.
- Los efectos respetan los límites:
  - habilidad entre 1 y potencial.
  - potencial entre habilidad y 99.
  - moral y reputación entre 0 y 100.
  - multiplicador de valor entre 0,2 y 5,0.
- Al terminar se recalculan los valores de mercado afectados.
- `limitarCostoEvento(int costoBase, int dineroActual)` es público para poder
  probarlo y para que la interfaz muestre exactamente lo que se cobrará.
- `multiplicadorFrecuencia(FrecuenciaEventos)` también es público.

### 4.6 Integración en `lib/logica/motor_juego.dart`

- Getters/acciones nuevas:
  - `List<EventoPendiente> get eventosPendientes`.
  - `Future<ResultadoAccion> resolverEvento(EventoPendiente evento, int opcion)`.
  - `Future<void> cambiarFrecuenciaEventos(FrecuenciaEventos frecuencia)`.
- `avanzarSemana` (orden nuevo):
  1. Lo que ya existe: simulación, mercado, renovaciones, ofertas, suplentes,
     salarios, oficina, contratos y progreso.
  2. Avance de semana/temporada y premios (ya existe).
  3. **Descontar** `semanasInactivo`, `semanasInversor` y
     `semanasContactoGrande` (después de que la semana los haya usado).
  4. Si no hay bancarrota, **generar los eventos de la semana** y añadir los
     pendientes y las noticias del mundo.
  5. Guardar y notificar.
- Comisiones: helper `_comisionNeta(int bruta)` que aplica el 10 % del inversor
  si está activo. Se usa en salarios, traspasos y renovaciones.
- Negociación: si `semanasContactoGrande > 0` y el equipo tiene prestigio ≥ 85,
  se pasa `margenExtraAceptacion = 0.10` a `calcularRespuesta`.
- `_nuevaTemporada`: pone `semanasInactivo = 0` a todos (recuperación de
  pretemporada). No borra eventos pendientes ni los efectos temporales.
- Cualquier efecto que añada/elimine jugadores o cambie equipos reconstruye
  los índices (`_reconstruirIndices`) y recalcula valores.

### 4.7 Ajustes a otros archivos de lógica

- `lib/logica/negociacion.dart`: `calcularRespuesta` acepta
  `double margenExtraAceptacion = 0`; el límite de aceptación pasa a
  `1.05 + margenExtraAceptacion`.
- `lib/logica/simulador_partidos.dart`:
  - Nuevo helper `alineacionDe(equipo, jugadores)` que excluye a los inactivos,
    prefiere titulares y completa con suplentes/disponibles.
  - `poderEquipo`, `simularSerie` y `simularEnfrentamiento` usan esa alineación.
- `lib/pantallas/pantalla_previa_partido.dart`: el poder y el duelo clave usan
  la misma alineación disponible.
- Los jugadores inactivos **no suman estadísticas** ni moral de partido porque
  no entran en la alineación.

---

## 5. INTERFAZ

### 5.1 `lib/pantallas/pantalla_eventos.dart` (nuevo)

- Función `Future<void> mostrarEventosPendientes(BuildContext, MotorJuego)`.
- Recorre una copia de `motor.eventosPendientes` y muestra un `AlertDialog`
  por evento, con `barrierDismissible: false`.
- Contenido:
  - Título del evento.
  - Descripción (con el nick ya interpolado).
  - Costo visible si la opción elegida cuesta dinero.
  - Botón **Entendido** si es informativo; dos botones si tiene decisión.
- Si una opción cuesta dinero:
  1. Se muestra el costo limitado al 30 % del dinero actual.
  2. Se abre `mostrarConfirmacion` antes de cobrar.
  3. Si se cancela, el evento sigue pendiente.
- Al resolver, se pasa al siguiente evento. Si se cierra la app a mitad, los
  pendientes se conservan en el guardado.

### 5.2 `lib/pantallas/pantalla_principal.dart`

- Después de `avanzarSemana` y de `avanzarSemanas(10)`, mostrar primero los
  eventos pendientes y después la ceremonia de premios si toca.
- Al entrar a la pantalla principal (por ejemplo al pulsar **Continuar**),
  mostrar los eventos pendientes que se hayan guardado.
- Evitar mostrar dos veces la misma tanda con un indicador de estado.

### 5.3 `lib/pantallas/pantalla_ajustes.dart`

- Nueva tarjeta **Eventos**:
  - Selector `SegmentedButton<FrecuenciaEventos>` con Baja / Normal / Alta.
  - Texto de ayuda: "Más frecuencia = más eventos por semana (máximo 3)."
  - Al cambiar, llamar a `motor.cambiarFrecuenciaEventos`.
- Mostrar, si están activos, "Inversor: X semanas" y
  "Contacto en equipo grande: X semanas".

### 5.4 Fichas y tarjetas

- `pantalla_detalle_jugador.dart`: chip rojo "Fuera X semanas" cuando
  `semanasInactivo > 0`.
- `widgets/tarjeta_jugador.dart`: ícono de alerta/médico cuando el jugador está
  inactivo.
- `pantalla_detalle_equipo.dart`: marcar a los titulares/suplentes inactivos.

---

## 6. ARCHIVOS A CREAR

- `PLAN_2E.md` (este documento).
- `lib/modelos/evento.dart`.
- `lib/logica/eventos.dart`.
- `lib/pantallas/pantalla_eventos.dart`.
- `test/eventos_test.dart`.

## 7. ARCHIVOS A MODIFICAR

| Archivo | Cambio |
|---|---|
| `lib/modelos/jugador.dart` | `semanasInactivo` + serialización tolerante. |
| `lib/modelos/estado_partida.dart` | Eventos pendientes, frecuencia, inversor, contacto; versión 6. |
| `lib/logica/negociacion.dart` | Margen extra de aceptación. |
| `lib/logica/simulador_partidos.dart` | Alineación con jugadores disponibles. |
| `lib/logica/motor_juego.dart` | Generación/resolución de eventos, temporizadores, comisiones con inversor, contacto grande, frecuencia. |
| `lib/pantallas/pantalla_eventos.dart` | Nuevo (ventana emergente). |
| `lib/pantallas/pantalla_principal.dart` | Mostrar eventos al avanzar y al cargar. |
| `lib/pantallas/pantalla_ajustes.dart` | Frecuencia de eventos y estado de efectos temporales. |
| `lib/pantallas/pantalla_detalle_jugador.dart` | Chip de jugador inactivo. |
| `lib/pantallas/pantalla_detalle_equipo.dart` | Marca de inactivo en la plantilla. |
| `lib/pantallas/pantalla_previa_partido.dart` | Alineación disponible. |
| `lib/widgets/tarjeta_jugador.dart` | Indicador de inactivo. |
| `lib/servicios/guardado.dart` | Solo actualizar comentarios de versión (la lógica ya usa las constantes). |
| `PROGRESO.md` y `HISTORIAL_FASE2.md` | Resumen y guía de prueba de 2E. |

---

## 8. ORDEN DE TRABAJO NUMERADO

1. **Crear este plan** en `PLAN_2E.md` y mostrarlo antes de programar.
2. **`Jugador`**: añadir `semanasInactivo` y `estaInactivo`, con serialización
   tolerante.
3. **`modelo/evento.dart`**: crear `FrecuenciaEventos` y `EventoPendiente`
   (con `toJson`/`fromJson`).
4. **`EstadoPartida`**: añadir los 4 campos nuevos, subir `versionFormato` a 6,
   mantener `versionMinimaCompatible = 3` y serialización tolerante.
5. **`eventos.dart` (base)**: constantes de balance, `AmbitoEvento`,
   `ContextoEventos`, `DefinicionEvento`, `OpcionEvento` y helpers
   `limitarCostoEvento` / `multiplicadorFrecuencia`.
6. **`eventos.dart` (catálogo)**: implementar todos los eventos de las tablas
   4.3 y sus condiciones/efectos, incluyendo el texto con `{nick}`.
7. **`eventos.dart` (generación)**: selección ponderada, límite de 3 por
   semana, 1 de agencia y 1 del mundo, y eventos del mundo aplicados como
   noticia.
8. **`eventos.dart` (resolución)**: aplicar opción elegida, respetar límites,
   generar noticia, devolver si hay que reconstruir índices.
9. **`negociacion.dart`**: añadir `margenExtraAceptacion` a
   `calcularRespuesta`.
10. **`simulador_partidos.dart`**: crear `alineacionDe`, excluir inactivos y
    usarla en poder/simulación.
11. **`motor_juego.dart` (eventos)**: integrar generación al final de
    `avanzarSemana`, temporizadores, `eventosPendientes`,
    `resolverEvento` y `cambiarFrecuenciaEventos`.
12. **`motor_juego.dart` (economía/negociación)**: helper `_comisionNeta` con
    inversor, aplicarlo a las 3 comisiones, y pasar el margen de contacto
    grande en `ofrecer`.
13. **`motor_juego.dart` (efectos de jugador)**: soportar inactividad, quedar
    libre, cambio de juego/rol, retiradas y reposición de titulares; resetear
    inactividad en `_nuevaTemporada`.
14. **`pantalla_eventos.dart`**: ventana emergente con botones, costo visible y
    confirmación de gastos.
15. **`pantalla_principal.dart`**: mostrar eventos tras avanzar y al cargar,
    antes de la ceremonia de premios.
16. **`pantalla_ajustes.dart`**: selector de frecuencia y estado de inversor /
    contacto grande.
17. **Fichas**: chip/indicador de inactivo en detalle de jugador, tarjeta y
    plantilla del equipo.
18. **`pantalla_previa_partido.dart`**: usar la alineación disponible.
19. **Actualizar comentarios de versión** en `guardado.dart` y en
    `estado_partida.dart`.
20. **Pruebas**: crear `test/eventos_test.dart` (costos, frecuencia,
    serialización, resolución de eventos, compatibilidad de campos ausentes) y
    ejecutar `flutter analyze` + `flutter test`. Corregir todo.
21. **Compilar y abrir**: `flutter build linux --debug` y `flutter run -d linux`
    (o el binario con `timeout`) para comprobar que la app arranca.
22. **Documentación**: añadir la sección 2E a `PROGRESO.md` y
    `HISTORIAL_FASE2.md` con la guía de prueba paso a paso.
23. **Revisión final** de la lista de pruebas de la sección 9.

---

## 9. PRUEBAS DE LA PARTE 2E

- [ ] Al avanzar semanas aparecen eventos en una ventana emergente, uno tras otro.
- [ ] Los eventos informativos se cierran con **Entendido** y dejan noticia.
- [ ] Los eventos con decisión funcionan en **ambas** opciones.
- [ ] Elegir una opción con costo muestra el costo y pide confirmación; cancelar
      no cobra y mantiene el evento.
- [ ] Ningún evento cobra más del 30 % del dinero actual, ni siquiera si el
      costo base es mayor.
- [ ] La frecuencia Baja / Normal / Alta cambia la cantidad de eventos y se
      guarda en la partida.
- [ ] Un jugador lesionado no aparece en la alineación ni suma poder, y vuelve
      a jugar al terminar sus semanas.
- [ ] El inversor descuenta el 10 % de las comisiones durante 26 semanas.
- [ ] El contacto con un equipo grande da +0,10 de margen durante 4 semanas.
- [ ] La fuga de información crea una oferta de traspaso válida.
- [ ] Los eventos del mundo solo generan noticias y no abren ventana.
- [ ] Se respeta el máximo de 3 eventos nuevos por semana.
- [ ] Una partida v5 se carga y se reguarda como v6 sin perder datos.
- [ ] `flutter analyze` no muestra errores.
- [ ] `flutter test` pasa completo.
- [ ] La app compila y abre en Linux.

---

## 10. NOTAS DE IMPLEMENTACIÓN

- Los textos visibles van en español.
- No se añaden paquetes.
- Los comentarios del código nuevo explican en simple qué hace cada evento y
  por qué se limita el costo.
- Las probabilidades, montos, duraciones y pesos quedan como constantes al
  inicio de `eventos.dart` para ajustar el balance sin tocar la lógica.
- Si un evento pendiente guardado ya no existe en el catálogo, se descarta con
  una noticia y no se rompe la partida.
- Los eventos del mundo no crean equipos nuevos: la noticia de "organización
  que entra a otro videojuego" es solo informativa para no alterar las ligas.
