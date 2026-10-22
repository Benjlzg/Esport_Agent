# PLAN DEL PROYECTO: ESPORTS AGENT

> Documento de diseño y desarrollo. OpenCode debe leer este archivo completo antes de programar
> y trabajar **una fase a la vez**, sin adelantarse a fases futuras.

---

## 0. REGLAS PARA OPENCODE (leer primero)

1. **Trabaja solo en la fase que se te pida.** No implementes cosas de fases futuras.
2. **Antes de escribir código**, muestra un resumen de los archivos que vas a crear o modificar y espera aprobación.
3. **El usuario es principiante.** Comenta el código en español, con explicaciones simples.
4. **Usa la menor cantidad de paquetes posible.** Si necesitas un paquete externo, di su **nombre exacto**, para qué sirve y pide permiso antes de agregarlo.
   - Paquete permitido desde la Fase 1: `shared_preferences` (guardar la partida).
   - Para manejar el estado del juego usa `ChangeNotifier` y `ListenableBuilder`, que vienen incluidos en Flutter (NO usar `provider`, `riverpod`, `bloc` ni `getx`).
   - Para convertir datos a texto usa `dart:convert`, que viene incluido en Dart.
5. **No descargues imágenes de internet.** Los escudos los agrega el usuario manualmente.
6. **Al terminar cada fase:**
   - Ejecuta `flutter analyze` y corrige todos los errores.
   - Ejecuta la app con `flutter run -d linux` para comprobar que abre.
   - Explica al usuario cómo probar lo nuevo, paso a paso.
7. **Crear el proyecto:** la carpeta se llama `Esport_Agent` (con mayúsculas), y Flutter solo acepta nombres en minúsculas. Crea el proyecto así, dentro de la carpeta actual:
   ```bash
   flutter create --project-name esport_agent --platforms=linux,android .
   ```
   No borres el archivo `PLAN.md`.
8. Todos los textos visibles de la app van **en español**.
9. Toda decisión cara o irreversible en el juego (gastar más del 20% del dinero, despedir, vender) debe mostrar un **diálogo de confirmación**.

---

## 1. VISIÓN DEL JUEGO

**Esports Agent** es un juego de gestión para celular, inspirado en *Soccer Agent*, pero ambientado en los Esports profesionales.

El jugador es un **agente de jugadores profesionales**. Empieza con poco dinero y poca reputación, y debe:

- Descubrir y **reclutar** jugadores con talento.
- **Ofrecerlos** a equipos reales y negociar contratos.
- Ganar **comisiones** para hacer crecer su agencia.
- Subir su **reputación** para atraer a jugadores estrella.
- A largo plazo, convertirse en el agente más poderoso del mundo e incluso **comprar un equipo**.

**Estilo:** juego de menús y tarjetas (no hay partidas jugables en tiempo real). Todo se simula con números y probabilidades.

**Lecciones del juego original (según reseñas de usuarios) que debemos mejorar:**
- Evitar que el juego sea repetitivo o "de puro tocar botones": cada semana debe pasar algo interesante.
- Confirmación antes de gastar mucho dinero (hubo quejas por gastos accidentales).
- Sin anuncios ni compras dentro de la app.
- Incluir cláusulas de recompra y mostrar salarios completos.

---

## 2. TECNOLOGÍA

| Elemento | Elección |
|---|---|
| Framework | Flutter (Dart) |
| Plataformas | Linux (para probar en PC) y Android |
| Estado del juego | `ChangeNotifier` + `ListenableBuilder` (incluidos en Flutter) |
| Guardado | Paquete `shared_preferences` + `dart:convert` (JSON) |
| Imágenes | Archivos locales en `assets/escudos/` |
| Paquetes externos | Solo `shared_preferences` en la Fase 1 |

---

## 3. ESTRUCTURA DE CARPETAS

```
Esport_Agent/
├── PLAN.md
├── pubspec.yaml
├── assets/
│   └── escudos/              ← el usuario pone aquí los escudos (ej: t1.png)
│       └── LEEME.txt         ← explica cómo nombrar los archivos
└── lib/
    ├── main.dart             ← punto de entrada de la app
    ├── tema/
    │   └── tema_app.dart     ← colores, estilos, tipografía
    ├── modelos/
    │   ├── juego.dart        ← enum de videojuegos y sus roles
    │   ├── jugador.dart
    │   ├── equipo.dart
    │   ├── agente.dart
    │   ├── noticia.dart
    │   └── estado_partida.dart
    ├── datos/
    │   ├── equipos_iniciales.dart    ← equipos reales (editable)
    │   ├── jugadores_iniciales.dart  ← jugadores reales (editable)
    │   └── nombres_aleatorios.dart   ← nombres y nicks para generar jóvenes
    ├── logica/
    │   ├── motor_juego.dart          ← ChangeNotifier principal
    │   ├── formulas.dart             ← cálculos de valor, salario, etc.
    │   ├── generador_jugadores.dart  ← crea jugadores jóvenes aleatorios
    │   └── negociacion.dart          ← lógica de ofertas y contraofertas
    ├── servicios/
    │   └── guardado.dart             ← guardar/cargar partida
    ├── pantallas/
    │   ├── pantalla_inicio.dart
    │   ├── pantalla_crear_agente.dart
    │   ├── pantalla_principal.dart   ← contiene la barra inferior de pestañas
    │   ├── pestana_resumen.dart
    │   ├── pestana_mis_jugadores.dart
    │   ├── pestana_mercado.dart
    │   ├── pestana_equipos.dart
    │   ├── pestana_noticias.dart
    │   ├── pantalla_detalle_jugador.dart
    │   ├── pantalla_detalle_equipo.dart
    │   ├── pantalla_negociacion.dart
    │   └── pantalla_ajustes.dart
    └── widgets/
        ├── escudo_equipo.dart        ← imagen o círculo con iniciales
        ├── tarjeta_jugador.dart
        ├── barra_habilidad.dart
        ├── indicador_dinero.dart
        └── dialogo_confirmacion.dart
```

En `pubspec.yaml` declarar la carpeta de assets:
```yaml
flutter:
  assets:
    - assets/escudos/
```

---

## 4. VIDEOJUEGOS Y ROLES

| Videojuego | Roles |
|---|---|
| League of Legends | Top, Jungla, Mid, ADC, Support |
| Valorant | Duelista, Iniciador, Controlador, Centinela, Flex |
| Counter-Strike 2 | IGL, AWPer, Entry, Rifler, Support |
| Dota 2 | Carry, Mid, Offlane, Soporte 4, Soporte 5 |

Cada equipo tiene **5 jugadores titulares**, uno por rol.

---

## 5. MODELOS DE DATOS

Todos los modelos deben tener métodos `toJson()` y `fromJson()` para poder guardarse.

### 5.1 Jugador
| Campo | Tipo | Descripción |
|---|---|---|
| id | String | Identificador único (ej: "lol_0001") |
| nick | String | Nombre de jugador (ej: "Faker") |
| nombreReal | String | Nombre real |
| pais | String | País (texto, ej: "Corea del Sur") |
| edad | int | 16 a 35 |
| juego | Juego | Videojuego |
| rol | String | Rol dentro del juego |
| habilidad | int | 1 a 100, nivel actual |
| potencial | int | 1 a 100, nivel máximo posible (siempre ≥ habilidad) |
| moral | int | 0 a 100, empieza en 70 |
| equipoId | String? | Equipo actual (null = agente libre) |
| salarioAnual | int | En dólares |
| semanasContrato | int | Semanas que le quedan de contrato |
| representadoPorMi | bool | Si es parte de mi agencia |
| esReal | bool | true = jugador real, false = generado |

### 5.2 Equipo
| Campo | Tipo | Descripción |
|---|---|---|
| id | String | Ej: "t1" (también es el nombre del archivo del escudo) |
| nombre | String | Ej: "T1" |
| juego | Juego | Videojuego |
| region | String | Ej: "Corea", "Europa", "Norteamérica", "Brasil", "China" |
| prestigio | int | 1 a 100 |
| presupuesto | int | Dinero disponible para fichajes |
| colorPrincipal | int | Color en formato 0xFFRRGGBB (para el círculo con iniciales) |

### 5.3 Agente
| Campo | Tipo | Descripción |
|---|---|---|
| nombre | String | Nombre del jugador humano |
| pais | String | País |
| dinero | int | Empieza en 50.000 |
| reputacion | int | 0 a 100, empieza en 10 |
| semanasEnNegativo | int | Para controlar la bancarrota |

### 5.4 Noticia
| Campo | Tipo |
|---|---|
| semana | int |
| temporada | int |
| texto | String |
| tipo | enum: fichaje, venta, progreso, dinero, evento, alerta |

### 5.5 EstadoPartida
Contiene: agente, lista de jugadores, lista de equipos, lista de noticias, semana actual (1 a 52), temporada actual (empieza en 1), y ofertas pendientes.

---

## 6. DATOS INICIALES

### 6.1 Equipos reales (archivo `equipos_iniciales.dart`)

Incluir este comentario al inicio del archivo:
```dart
// IMPORTANTE: Las organizaciones y plantillas pueden haber cambiado.
// Revisa y corrige estos datos cuando quieras. Las líneas marcadas con
// "VERIFICAR" son las que más conviene revisar.
```

| Videojuego | Equipos |
|---|---|
| League of Legends | T1, Gen.G, G2 Esports, Fnatic, Team Liquid, Bilibili Gaming |
| Valorant | Sentinels, Fnatic, Paper Rex, LOUD, Team Heretics, Leviatán |
| Counter-Strike 2 | Team Vitality, Natus Vincere, FaZe Clan, MOUZ, Team Spirit, FURIA |
| Dota 2 | Team Spirit, Team Liquid, Gaimin Gladiators, Tundra Esports, Team Falcons, BetBoom Team |

Si un mismo club está en varios juegos (ej: Fnatic), se crean como equipos separados con ids distintos (ej: `fnatic_lol`, `fnatic_val`), pero pueden compartir escudo (`fnatic.png`). Agregar un campo `escudo` al equipo para indicar el nombre del archivo.

Prestigio sugerido: equipos de élite 85–95, equipos fuertes 70–84. Presupuesto = prestigio × 20.000.

### 6.2 Jugadores reales (archivo `jugadores_iniciales.dart`)

- Completar las plantillas (5 por equipo) con los jugadores reales que conozcas.
- Marca **cada jugador real** con el comentario `// VERIFICAR`, porque las plantillas cambian seguido.
- Si no conoces con seguridad algún jugador, usa el generador para rellenar ese puesto (esReal = false).
- Habilidad de titulares: entre 65 y 95 según el nivel del equipo.

### 6.3 Agentes libres y jóvenes talentos

Al iniciar la partida, generar **40 jugadores libres** (10 por videojuego) con `generador_jugadores.dart`:
- Edad: 16 a 24.
- Habilidad: 35 a 70.
- Potencial: habilidad + entre 5 y 30 (máximo 99).
- Nicks generados combinando palabras de `nombres_aleatorios.dart` (ej: "Shadow", "Kira", "Vex", "Nova" + números o sufijos).
- Países variados, incluyendo Latinoamérica (Chile, Argentina, Brasil, México, Perú).

---

## 7. FÓRMULAS Y REGLAS DEL JUEGO

Todas las fórmulas van en `formulas.dart`, como funciones simples y bien comentadas, para que el usuario pueda ajustar el balance fácilmente. Usar constantes con nombre al inicio del archivo (ej: `const comisionTransferencia = 0.10;`).

### 7.1 Valor de mercado
```
valorBase = 1.000 × (habilidad / 10)³
```
Ejemplos: habilidad 50 → 125.000 · habilidad 70 → 343.000 · habilidad 90 → 729.000

Multiplicador por edad:
| Edad | Multiplicador |
|---|---|
| 16–19 | 1,3 |
| 20–23 | 1,2 |
| 24–26 | 1,0 |
| 27–29 | 0,8 |
| 30+ | 0,6 |

Bonus por potencial: `× (1 + (potencial − habilidad) / 100)`

```
valorMercado = valorBase × multiplicadorEdad × bonusPotencial   (redondeado a miles)
```

### 7.2 Salario
```
salarioAnual = valorMercado × 0,25
salarioSemanal = salarioAnual / 52
```
Mostrar siempre el salario **completo** (ej: "$85.750 al año"), formateado con puntos de miles.

### 7.3 Ingresos y gastos del agente
- **Comisión por transferencia:** 10% del valor del traspaso.
- **Comisión por salario:** cada semana gano el 5% del salario semanal de cada jugador que represento y que tiene equipo.
- **Costo de fichaje (representar a un jugador):** 5% de su valor de mercado, se paga una sola vez.
- **Gasto fijo de oficina:** $500 por semana.

### 7.4 ¿Acepta el jugador que lo represente?
El jugador acepta si: `reputacion del agente ≥ habilidad − 40`

- Un jugador de habilidad 50 acepta a un agente con reputación 10.
- Una estrella de habilidad 90 exige reputación 50 o más.
- Si rechaza, mostrar un mensaje del tipo: "*Nova prefiere un agente con más prestigio.*"

### 7.5 Ofrecer un jugador a un equipo (negociación)
1. El jugador debe ser de **mi agencia** y del **mismo videojuego** que el equipo.
2. El equipo se interesa si `habilidad del jugador ≥ prestigio del equipo − 20`.
3. El equipo tiene que poder pagar: `valorMercado ≤ presupuesto`.
4. Respuestas posibles:
   - **Acepta:** si el precio pedido ≤ valorMercado × 1,05.
   - **Contraoferta:** si el precio pedido está entre 1,05 y 1,40 del valor; el equipo ofrece un valor aleatorio entre 0,85 y 1,0 del valor de mercado.
   - **Rechaza:** si el precio pedido > 1,40 del valor, o si no se cumplen las condiciones 2 o 3.
5. Máximo **3 rondas** de negociación por jugador y equipo. Si se agotan, el equipo no quiere hablar más hasta la próxima temporada.
6. Al cerrar el trato:
   - El jugador pasa al nuevo equipo con contrato de 52 a 104 semanas.
   - Si el nuevo equipo tenía un jugador en ese rol, ese jugador queda **libre** (pasa al mercado).
   - El agente recibe su comisión del 10%.
   - El presupuesto del equipo baja.
   - Reputación del agente: `+1` normal, `+3` si el equipo tiene prestigio ≥ 85.
   - Se crea una noticia.

### 7.6 Progreso semanal de los jugadores
Cada semana, para cada jugador:
| Edad | Probabilidad | Cambio |
|---|---|---|
| ≤ 23 y habilidad < potencial | 30% | +1 o +2 |
| 24–27 | 15% | −1 o +1 |
| ≥ 28 | 20% | −1 |

- Si la moral es mayor a 80, la probabilidad de mejorar sube un 10%.
- Si la moral es menor a 30, no puede mejorar.
- La habilidad nunca supera el potencial ni baja de 1.
- Después de cambiar la habilidad, recalcular el valor de mercado.

### 7.7 Paso del tiempo
- Una temporada = **52 semanas**.
- Al terminar la temporada (semana 52 → semana 1):
  - Todos los jugadores suman 1 año de edad.
  - Los jugadores de 33 años o más tienen 30% de probabilidad de retirarse (noticia).
  - Se generan 12 nuevos jóvenes talentos (3 por videojuego).
  - Los presupuestos de los equipos se recargan: `prestigio × 20.000`.
- Los contratos bajan 1 semana cada semana. Si llegan a 0, el jugador queda libre (noticia).

### 7.8 Bancarrota
- Si el dinero queda en negativo, mostrar una alerta en rojo.
- Si pasan **8 semanas seguidas** en negativo: **fin del juego**, con pantalla que ofrece empezar de nuevo.

---

## 8. PANTALLAS (FASE 1)

### 8.1 Pantalla de inicio
- Logo de texto grande: "ESPORTS AGENT".
- Botón **Nueva partida**.
- Botón **Continuar** (solo si existe una partida guardada).
- Si hay una partida guardada y se elige "Nueva partida", pedir confirmación.

### 8.2 Crear agente
- Campo de texto: nombre del agente.
- Lista desplegable: país (incluir Chile, Argentina, México, Perú, Colombia, España, Brasil, Estados Unidos, Corea del Sur y otros).
- Botón **Empezar carrera** → crea la partida con $50.000 y reputación 10.

### 8.3 Pantalla principal
Barra inferior con 5 pestañas:
1. **Resumen**
2. **Mi agencia**
3. **Mercado**
4. **Equipos**
5. **Noticias**

Barra superior fija con: dinero, reputación, "Temporada X · Semana Y", y un ícono de ajustes.

Botón flotante grande **"Avanzar semana ▶"** visible en todas las pestañas.

### 8.4 Pestaña Resumen
- Tarjeta con dinero y cuánto ganaste/gastaste la semana pasada.
- Tarjeta de reputación con barra de progreso.
- Mis 3 jugadores más valiosos.
- Las últimas 5 noticias.

### 8.5 Pestaña Mi agencia
- Lista de los jugadores que represento (tarjeta de jugador).
- Si no hay ninguno: mensaje "Aún no representas a nadie. Ve al Mercado para reclutar tu primer jugador."
- Tocar un jugador → Detalle del jugador.

### 8.6 Pestaña Mercado
- Filtros arriba: por videojuego (chips: Todos, LoL, Valorant, CS2, Dota 2), y orden (valor, habilidad, potencial, edad).
- Opción para ver: "Agentes libres" o "Todos los jugadores".
- Lista de tarjetas de jugadores.

### 8.7 Pestaña Equipos
- Filtro por videojuego.
- Lista de equipos con escudo, nombre, región, prestigio y presupuesto.
- Tocar → Detalle del equipo.

### 8.8 Pestaña Noticias
- Lista cronológica (más reciente arriba), con ícono y color según el tipo.

### 8.9 Detalle del jugador
- Nick grande, nombre real, país, edad, videojuego y rol.
- Escudo y nombre del equipo actual (o "Agente libre").
- Barras de habilidad, potencial y moral.
- Valor de mercado y salario anual completo.
- Semanas de contrato restantes.
- Botones según la situación:
  - **Reclutar** (si no lo represento): muestra el costo y pide confirmación.
  - **Ofrecer a un equipo** (si lo represento): lleva a la pantalla de negociación.
  - **Dejar de representar** (si lo represento): pide confirmación.

### 8.10 Detalle del equipo
- Escudo grande, nombre, región, videojuego, prestigio y presupuesto.
- Plantilla de 5 jugadores, mostrando el rol de cada uno.

### 8.11 Negociación
- Elegir equipo (solo equipos del mismo videojuego del jugador).
- Indicador de interés del equipo ("Muy interesado", "Interesado", "Sin interés").
- Campo para escribir el precio pedido, con un valor sugerido igual al valor de mercado.
- Botón **Enviar oferta**.
- Mostrar la respuesta: aceptada / contraoferta (con botones **Aceptar** o **Pedir más**) / rechazada.
- Contador de rondas restantes.

### 8.12 Ajustes
- Ver nombre del agente y temporada.
- Botón **Borrar partida** (con doble confirmación).

---

## 9. COMPONENTES REUTILIZABLES (widgets)

- **EscudoEquipo:** recibe el equipo y un tamaño. Intenta cargar `assets/escudos/<escudo>.png` con `Image.asset` y, si falla (`errorBuilder`), muestra un círculo con el `colorPrincipal` del equipo y sus iniciales en blanco (ej: "TL" para Team Liquid).
- **TarjetaJugador:** nick, rol, edad, bandera o país, habilidad, potencial, valor, y escudo del equipo.
- **BarraHabilidad:** barra horizontal de color según el valor (rojo < 50, amarillo 50–74, verde 75–89, dorado ≥ 90).
- **IndicadorDinero:** formatea montos así: "$1.250.000". Si es negativo, en rojo.
- **DialogoConfirmacion:** título, mensaje, botón "Cancelar" y "Confirmar".

---

## 10. DISEÑO VISUAL

Estilo oscuro tipo "gamer", moderno y limpio.

| Uso | Color |
|---|---|
| Fondo | #0D0F14 |
| Tarjetas / superficies | #171A21 |
| Acento principal | #7C4DFF (violeta) |
| Acento secundario | #00E5FF (celeste neón) |
| Éxito / ganancias | #00C853 |
| Peligro / pérdidas | #FF5252 |
| Dorado (estrellas) | #FFD54F |
| Texto principal | #FFFFFF |
| Texto secundario | #9AA0A6 |

- Bordes redondeados (12 px) en tarjetas y botones.
- Usar Material 3 (`useMaterial3: true`) con tema oscuro.
- Íconos de Material (vienen incluidos en Flutter).
- Diseñado para pantalla de celular vertical, pero que no se rompa en la ventana de Linux.

---

## 11. GUARDADO

- Archivo `guardado.dart` con funciones: `guardarPartida(estado)`, `cargarPartida()`, `existePartida()`, `borrarPartida()`.
- Usa el paquete `shared_preferences` con la clave `"partida_esports_agent"`.
- El estado se convierte a texto JSON con `jsonEncode` / `jsonDecode` de `dart:convert`.
- **Guardar automáticamente** después de: avanzar semana, reclutar, vender, dejar de representar.
- Incluir un campo `"version": 1` en el JSON, para poder actualizar el formato en el futuro.

---

## 12. FASES DEL PROYECTO (HOJA DE RUTA)

### ✅ FASE 1 — Versión básica jugable
Todo lo descrito en las secciones 1 a 11: crear agente, mercado, reclutar, ofrecer, negociar, comisiones, avanzar semana, progreso de jugadores, temporadas, noticias, guardado y bancarrota.

### FASE 2 — Mundo vivo (ver `PLAN_FASE2.md`)
Regiones con Primera y Segunda División, cientos de equipos, ligas, previsualización de partidos, forma, estadísticas, rivalidades, torneos internacionales, premios individuales (Jugador del Año, Máximo Eliminador), ascensos y descensos, fichajes de la IA, ofertas, renovaciones y eventos aleatorios.

### FASE 2.5 — Pruebas de balance (antes de seguir agregando cosas)
- **Semillas reproducibles:** el generador de números aleatorios del motor acepta una "semilla" opcional, para repetir exactamente la misma partida al buscar errores.
- **Simulador automático de temporadas** (`test/balance_test.dart` o un comando aparte): crea una partida, avanza **10 temporadas** sin intervención del usuario y genera un informe `INFORME_BALANCE.md` con:
  - Dinero total de los equipos al inicio y al final de cada temporada (¿hay inflación?).
  - Cuántos títulos ganó cada equipo (¿siempre gana el mismo?).
  - Promedio de habilidad por videojuego cada temporada (¿los jugadores mejoran sin control o se vuelven todos malos?).
  - Valor de mercado máximo, promedio y mínimo (¿hay valores absurdos?).
  - Equipos con presupuesto negativo o plantillas incompletas.
  - Cantidad de fichajes de la IA por ventana (¿el mercado está bloqueado o descontrolado?).
  - Tiempo que tarda en avanzar una semana y una temporada (rendimiento).
- **Valores límite** en todas las fórmulas: ningún valor de mercado, presupuesto, habilidad o moral puede salirse de su rango (ni negativos imposibles ni crecimiento infinito).
- Ajustar las constantes de `formulas.dart` y `eventos.dart` según el informe, y repetir hasta que los números sean razonables.
- El informe debe basarse en números medidos, no en impresiones.

### FASE 3 — Ojeadores, staff, cantera, agentes rivales y relaciones
- **Agentes rivales controlados por la IA** (entre 8 y 15, con nombre, país, reputación y dinero):
  - Representan a jugadores y compiten contigo por los mismos talentos.
  - Cada agente tiene un **perfil**: conservador, cazador de jóvenes, agresivo (paga caro por estrellas) o comercial (vende rápido).
  - Siguen las **mismas reglas** que tú (no ven información oculta, respetan su dinero y las ventanas).
  - Si un jugador que te interesa ya tiene agente, puedes intentar convencerlo de cambiarse; depende de tu reputación y de su satisfacción con su agente actual.
  - Ranking de agentes; el premio **Agente del Año** pasa a compararte con ellos.
- **Expectativas y satisfacción de los representados:**
  - Cada jugador tiene 1 o 2 **expectativas** (ej: "ser titular", "ganar más sueldo", "jugar en Primera División", "jugar un Mundial", "irse a un equipo de prestigio ≥ 80").
  - Un nivel de **satisfacción** (0–100) con su agente que sube si cumples sus expectativas y baja si no.
  - Con satisfacción baja: pide hablar contigo, rechaza tus ofertas o termina la representación.
  - **Contrato de representación** con duración y porcentaje de comisión negociables.
- **Red de ojeadores por país o región**: contratar ojeadores (niveles 1 a 5, con costo semanal). Cada uno revisa una región.
- **Potencial oculto**: sin ojear, el potencial se muestra como rango estimado (ej: "70–90"); un ojeador mejor reduce el rango hasta mostrar el número exacto.
- **Talentos ocultos**: jugadores que solo aparecen en el mercado si tienes ojeador en su región (ej: jugadores de ranked de alto nivel).
- **Staff de la agencia**: entrenador (más progreso), analista (mejor previsualización), psicólogo (moral), fisioterapeuta (menos lesiones y recuperación rápida), negociador (mejores comisiones).
- **Cantera / academia propia**: firmar jugadores de 15–17 años, entrenarlos y colocarlos en equipos de Segunda División.

### FASE 4 — Economía de la agencia
- **Patrocinios** para la agencia según reputación, con requisitos (ej: "tener 3 jugadores en Primera División").
- **Instalaciones de la agencia** (niveles 1 a 5): oficina, gaming house, centro de entrenamiento. Suben gastos pero mejoran progreso, moral y reputación.
- **Préstamos** con interés.
- **Inversiones arriesgadas**: negocios con riesgo (ej: marca de ropa gamer, academia online, bar de esports) que pueden multiplicar o perder el dinero.
- **Libro contable:** cada movimiento de dinero (comisión, gasto de oficina, sueldo de staff, evento, patrocinio, inversión...) se registra como una **transacción** con fecha, monto, categoría y origen. El dinero nunca cambia sin registrar su transacción.
- Pantalla **Finanzas**: lista de transacciones con filtros por categoría y temporada, resumen de ingresos y gastos, y alerta si el dinero va a quedar en negativo.
- Gráficos de ingresos y gastos por semana y por temporada (a partir del libro contable).

### FASE 5 — Contratos avanzados
- Negociar el **salario con el jugador** al reclutarlo (no solo el traspaso).
- Cláusulas: **rescisión**, **recompra**, **porcentaje de futura venta**, **bonos por títulos**.
- Duración del contrato a elección (1 a 4 temporadas).
- Historial de salarios por temporada en el detalle del jugador.

### FASE 6 — Bolsa de equipos
- Cada equipo de Primera División tiene **acciones** con un precio que sube o baja según resultados, títulos, fichajes y premios.
- Comprar y vender acciones; gráfico de precio por semana.
- Dividendos al final de la temporada para los equipos campeones.
- Tener el **51%** de un equipo desbloquea la Fase 7.

### FASE 7 — Presidente de club y de federación
- **Presidente de club**: gestionar plantilla, fichajes, sueldos, presupuesto y entrenador del equipo.
- **Instalaciones del club**: gaming house, centro de entrenamiento, arena para eventos, academia; mejoran resultados e ingresos.
- **Objetivos de la junta** cada temporada (ej: "llegar a playoffs"); si no se cumplen varias veces, te pueden destituir.
- **Presidente de federación** (de un videojuego o región): requiere mucha reputación. Permite cambiar el formato de la liga, el número de equipos (hasta 24), los premios y las reglas de fichajes.

### FASE 8 — Desafíos, predicciones y logros
- **Juego de predicción**: antes de cada fecha, adivinar ganadores de los partidos; los aciertos dan reputación o pequeñas recompensas (sin apostar dinero del juego).
- **Desafíos de tiempo limitado**: objetivos opcionales con premio (ej: "Lleva a un jugador menor de 20 años al Mundial en 2 temporadas").
- **Eventos especiales**: torneos de exhibición, All-Stars de fin de temporada.
- **Logros** permanentes (ej: "Primer millón", "Campeón del mundo", "Agente de 10 estrellas").

### FASE 9 — Leyendas e historia
- Ranking mundial de jugadores por videojuego (actual e histórico).
- Historial completo de cada jugador: equipos, títulos, premios, estadísticas por temporada.
- **Salón de la fama** de jugadores retirados, con su ascenso y caída.
- Récords históricos (más títulos, más eliminaciones, traspaso más caro).

### FASE 10 — Pulido y Android
- Tutorial para jugadores nuevos.
- **Avanzar hasta el próximo evento importante:** botón que avanza semanas automáticamente y se detiene cuando llega una oferta, un evento con decisión, un partido de tus jugadores en playoffs o torneos, o se abre una ventana de fichajes.
- Revisar que todos los botones tengan estados claros (cargando, éxito y error) y que ninguna pantalla tenga controles que no hagan nada.
- Animaciones suaves (al fichar, al subir de habilidad, en la ceremonia de premios).
- Sonidos opcionales.
- Ícono de la app y pantalla de carga.
- Generar el archivo APK para instalar en Android: `flutter build apk`.

---

## 13. LISTA DE PRUEBAS DE LA FASE 1

Al terminar la Fase 1, todo esto debe funcionar:

- [ ] La app abre con `flutter run -d linux` sin errores.
- [ ] `flutter analyze` no muestra errores.
- [ ] Puedo crear un agente y empiezo con $50.000 y reputación 10.
- [ ] El mercado muestra jugadores de los 4 videojuegos y los filtros funcionan.
- [ ] Puedo reclutar a un jugador libre y se descuenta el 5% de su valor.
- [ ] Una estrella con habilidad alta rechaza representarme al inicio.
- [ ] Puedo ofrecer a mi jugador a un equipo y recibo aceptación, contraoferta o rechazo.
- [ ] Al vender, recibo el 10% y aparece una noticia.
- [ ] Al avanzar la semana, cambia la semana, se cobra la oficina y se paga la comisión de salarios.
- [ ] Los jugadores jóvenes mejoran con el tiempo y los mayores empeoran.
- [ ] Al pasar la semana 52 empieza una nueva temporada y los jugadores envejecen.
- [ ] Si cierro la app y la abro de nuevo, puedo pulsar "Continuar" y sigo donde estaba.
- [ ] Si no existe el escudo de un equipo, se ven sus iniciales en un círculo de color.
- [ ] Al poner `t1.png` en `assets/escudos/` y reiniciar la app, aparece el escudo de T1.
- [ ] Todas las acciones caras piden confirmación.
