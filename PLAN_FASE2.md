# PLAN FASE 2: MUNDO VIVO — ESPORTS AGENT

> Este documento **reemplaza la Fase 2 y la parte de eventos aleatorios de la Fase 5** de `PLAN.md`.
> Las reglas de la sección 0 de `PLAN.md` siguen vigentes (paquetes, comentarios en español, confirmaciones, `flutter analyze`, etc.).
>
> La Fase 2 se divide en **5 partes (2A a 2E)**. OpenCode debe hacer **una sola parte por sesión**, en orden.
> Antes de empezar cada parte, leer este archivo, revisar el código existente y mostrar la lista de archivos a crear/modificar.

---

## RESUMEN DE LAS PARTES

| Parte | Contenido | Resultado |
|---|---|---|
| **2A** | Mundo: regiones, muchos más equipos, datos en archivos JSON | El juego tiene cientos de equipos organizados por región y división |
| **2B** | Calendario, ligas regionales, partidos simulados, tablas y playoffs | Cada semana se juegan partidos y hay campeones regionales |
| **2C** | Torneos internacionales, premios en dinero, ascensos y descensos | Hay torneo de mitad de temporada y Mundial |
| **2D** | Mercado vivo: los equipos de la IA fichan, ventanas de fichajes, ofertas por mis jugadores, renovaciones | El mundo se mueve aunque yo no haga nada |
| **2E** | Eventos aleatorios | Cada semana pueden pasar cosas que suben o bajan a los jugadores |

---

# PARTE 2A — EL MUNDO: REGIONES Y EQUIPOS

## 2A.1 Datos en archivos JSON (más fáciles de editar)

Mover los equipos y jugadores reales desde archivos `.dart` a archivos **JSON** dentro de `assets/datos/`:

```
assets/datos/
├── regiones.json
├── equipos_lol.json
├── equipos_valorant.json
├── equipos_cs2.json
├── equipos_dota2.json
└── LEEME.txt          ← explica cómo agregar o corregir equipos y jugadores
```

- Cargar los JSON con `rootBundle.loadString()` (incluido en Flutter, **no requiere paquetes**).
- Declarar `assets/datos/` en `pubspec.yaml`.
- Cada equipo en el JSON tiene: `id`, `nombre`, `escudo`, `region`, `division` (1 o 2), `prestigio`, `colorPrincipal`, `esReal`, y una lista opcional `jugadores` con jugadores reales (`nick`, `nombreReal`, `pais`, `edad`, `rol`, `habilidad`, `potencial`).
- Si un equipo no tiene jugadores en el JSON, o le faltan, **el juego genera los que falten** al crear la partida (jugadores ficticios, `esReal: false`).
- Agregar un campo `"verificar": true` a los datos reales que conviene revisar, porque las plantillas cambian seguido.

## 2A.2 Estructura del mundo

```
Videojuego → Región → División (1ª y 2ª) → Equipos (8 por división)
```

- Cada región tiene **Primera División** (8 equipos) y **Segunda División** (8 equipos).
- La Segunda División se llena con los equipos reales sobrantes de la lista y, si faltan, con **equipos ficticios generados** (nombres inventados combinando palabras como "Andes", "Cóndor", "Nova", "Storm", "Esports", "Gaming", "Club").
- Todos los nombres de ligas son **genéricos e inventados** (ej: "Liga Corea", "Liga Latinoamérica Sur"), para que el usuario pueda renombrarlos en `regiones.json`.

## 2A.3 Regiones por videojuego

### League of Legends
| Región | Equipos reales para usar (VERIFICAR) |
|---|---|
| Corea | T1, Gen.G, Hanwha Life Esports, KT Rolster, Dplus KIA, DRX, Nongshim RedForce, BNK FearX, OKSavingsBank BRION, DN Freecs |
| China | Bilibili Gaming, Top Esports, JD Gaming, Anyone's Legend, Weibo Gaming, Invictus Gaming, EDward Gaming, LNG Esports |
| Europa | G2 Esports, Fnatic, Movistar KOI, Karmine Corp, Team Vitality, Team Heretics, SK Gaming, GIANTX, Team BDS, Natus Vincere |
| Norteamérica | Cloud9, Team Liquid, FlyQuest, 100 Thieves, Dignitas, Shopify Rebellion, LYON, Disguised |
| Brasil | paiN Gaming, LOUD, FURIA, RED Canids, Vivo Keyd Stars, Fluxo W7M |
| Latinoamérica | Isurus, Estral Esports, Movistar R7, Six Karma, Leviatán |
| Pacífico | PSG Talon, CTBC Flying Oyster, GAM Esports, Team Secret Whales, DetonatioN FocusMe |

### Valorant
| Región | Equipos reales para usar (VERIFICAR) |
|---|---|
| Américas | Sentinels, LOUD, FURIA, MIBR, Leviatán, KRÜ Esports, 100 Thieves, Cloud9, Evil Geniuses, NRG, G2 Esports |
| EMEA | Fnatic, Team Heretics, Team Vitality, Karmine Corp, Natus Vincere, FUT Esports, BBL Esports, Team Liquid, GIANTX, Movistar KOI, Gentle Mates |
| Pacífico | Paper Rex, DRX, Gen.G, T1, Rex Regum Qeon, Talon Esports, Team Secret, Global Esports, ZETA DIVISION, DetonatioN FocusMe |
| China | EDward Gaming, Bilibili Gaming, FunPlus Phoenix, Trace Esports, Titan Esports Club, Dragon Ranger Gaming, JD Gaming, TYLOO, Wolves Esports |
| Latinoamérica Sur | 9z Team, Infinity, Australs (resto ficticios) |

### Counter-Strike 2
| Región | Equipos reales para usar (VERIFICAR) |
|---|---|
| Europa | Team Vitality, MOUZ, FaZe Clan, G2 Esports, Natus Vincere, Team Spirit, Astralis, Heroic, Team Falcons, Aurora, 3DMAX, Virtus.pro, Eternal Fire, GamerLegion, ENCE, BIG, Fnatic, Ninjas in Pyjamas |
| Norteamérica | Team Liquid, NRG, Complexity, M80, Wildcard |
| Sudamérica | FURIA, MIBR, paiN Gaming, Imperial, Legacy, 9z Team, Fluxo, ODDIK |
| Asia-Oceanía | The MongolZ, TYLOO, Lynn Vision, FlyQuest, Rare Atom |

### Dota 2
| Región | Equipos reales para usar (VERIFICAR) |
|---|---|
| Europa Occidental | Team Liquid, Gaimin Gladiators, Tundra Esports, OG, Team Secret |
| Europa del Este | Team Spirit, BetBoom Team, PARIVISION, Natus Vincere, Aurora, Virtus.pro |
| China | Xtreme Gaming, Azure Ray |
| Sudeste Asiático | Talon Esports, BOOM Esports, Execration |
| Norteamérica | Shopify Rebellion, Nouns, Wildcard |
| Sudamérica | HEROIC, beastcoast |
| Medio Oriente | Team Falcons, Nigma Galaxy |

**Reglas para repartir:**
- Los primeros 8 equipos de cada lista van a Primera División (ordenados por prestigio); el resto, a Segunda.
- Si una región tiene menos de 16 equipos, completar con equipos ficticios.
- Un mismo club en varios juegos se crea como equipos separados con id distinto (`fnatic_lol`, `fnatic_cs2`), pero comparte escudo (`fnatic.png`).

## 2A.4 Prestigio y presupuesto
| Tipo de equipo | Prestigio |
|---|---|
| Élite mundial | 85–95 |
| Fuerte de Primera División | 70–84 |
| Medio de Primera División | 55–69 |
| Segunda División | 35–54 |

- Presupuesto inicial = `prestigio × 20.000` (igual que antes).
- Habilidad de los jugadores generados: alrededor del prestigio del equipo ± 8.

## 2A.5 Interfaz
- Pestaña **Equipos**: filtros por videojuego → región → división.
- Detalle del equipo: mostrar región, división y liga.
- Mercado: agregar filtro por región.

## 2A.6 Partidas guardadas
- Subir la versión del guardado a `"version": 2`.
- Si se intenta cargar una partida de versión 1, mostrar un aviso: *"Tu partida es de una versión anterior y no es compatible. Debes empezar una nueva."* con botón para empezar de nuevo.

## 2A.7 Rendimiento
- Con cientos de equipos y miles de jugadores, usar `ListView.builder` en todas las listas (carga solo lo visible).
- Guardar los jugadores en un `Map<String, Jugador>` por id para buscarlos rápido.

---

# PARTE 2B — CALENDARIO, LIGAS Y PARTIDOS

## 2B.1 Calendario de la temporada (52 semanas)

| Semanas | Etapa |
|---|---|
| 1–4 | Pretemporada · **Ventana de fichajes 1** |
| 5–18 | **Split 1**: liga regional (ida y vuelta, 14 fechas) |
| 19–20 | **Playoffs del Split 1** (los 4 mejores: semifinal y final) |
| 21–22 | **Torneo Internacional de Mitad de Temporada** (Parte 2C) |
| 23–26 | **Ventana de fichajes 2** |
| 27–40 | **Split 2**: liga regional |
| 41–42 | **Playoffs del Split 2** |
| 43–46 | **Mundial** (Parte 2C) |
| 47–52 | Fin de temporada: ascensos, descensos, premios, **ventana de fichajes 3** (la más grande) |

- Mostrar en la barra superior la etapa actual (ej: "Split 1 · Fecha 6").
- Pantalla nueva **Calendario**: lista de etapas de la temporada marcando la actual.

## 2B.2 Simulación de partidos

**Poder del equipo:**
```
poder = promedio de habilidad de los 5 titulares × (1 + (moralPromedio − 50) / 500)
```

**Probabilidad de que gane A:**
```
probA = 1 / (1 + e^(−(poderA − poderB) / 6))
```
Ejemplo: si A tiene 6 puntos más de poder, gana el 73% de las veces.

**Formato:**
- Liga regular: series al mejor de 3 (gana quien gana 2 mapas/partidas; simular cada mapa con `probA`).
- Playoffs: al mejor de 5.
- Final del Mundial: al mejor de 5.

**Rendimiento individual:** después de cada serie, cada jugador recibe una **nota de 1,0 a 10,0**:
```
nota = 5 + (habilidad − 60) / 10 + azar(−2, +2) + (ganó ? 1 : −0,5)   (limitada entre 1 y 10)
```
Guardar en el jugador: partidas jugadas, victorias y nota promedio de la temporada.

## 2B.3 Tablas de posiciones
- Victoria = 3 puntos, derrota = 0.
- Desempate: diferencia de mapas ganados/perdidos.
- Pantalla nueva **Ligas**: elegir videojuego → región → división, y ver la tabla y los resultados de la última fecha.
- Resaltar los equipos donde juegan mis representados.

## 2B.4 Efectos de los resultados
- Victoria: +2 de moral a los titulares. Derrota: −2.
- Cada 4 semanas, el valor de mercado de un jugador se ajusta según su nota promedio: nota ≥ 7,5 → +5%; nota ≤ 4,5 → −5%.
- Noticias automáticas: resultados de mis jugadores, campeones de cada liga, rachas de 4+ victorias seguidas.

## 2B.5 Interfaz
- Agregar una pestaña **Competición** a la barra inferior (o un botón grande en Resumen) con: Calendario, Ligas, y más adelante Torneos.
- En el Resumen: "Próximos partidos de mis jugadores".

## 2B.6 Estado de forma
- Cada jugador tiene una **forma** de 1 a 5 estrellas, calculada con el promedio de sus **últimas 5 notas**:
  - nota ≥ 8 → 5 ★ · 7–7,9 → 4 ★ · 6–6,9 → 3 ★ · 5–5,9 → 2 ★ · < 5 → 1 ★
- La forma suma o resta al poder del equipo: cada titular aporta `(forma − 3) × 0,5` puntos.
- Mostrar la forma con estrellas en la tarjeta y el detalle del jugador.
- Los jugadores sin partidos recientes tienen forma 3.

## 2B.7 Estadísticas propias de Esports
Además de la nota, en cada serie cada jugador acumula:
- **Eliminaciones** (kills): `azar(5, 25) × (habilidad / 70)` por mapa, más alto en roles ofensivos (ADC, Mid, Duelista, AWPer, Entry, Carry) ×1,3, y más bajo en soportes ×0,6.
- **Muertes** y **asistencias** (valores aleatorios coherentes con el rol).
- **KDA** = (eliminaciones + asistencias) / máx(muertes, 1).
- **Premios MVP de la serie**: el jugador con mejor nota del equipo ganador.
Guardar totales por temporada y por carrera.

## 2B.8 Previsualización de partido
Antes de cada fecha, en la pantalla **Ligas** y en **Próximos partidos de mis jugadores**, mostrar para cada serie:
- Escudos y nombres de ambos equipos.
- Poder de cada equipo y su forma (últimos 5 resultados: V V D V D).
- **Probabilidad de victoria** de cada equipo (usando la fórmula de 2B.2), con una barra de dos colores.
- Enfrentamiento directo: resultados anteriores entre ambos.
- Duelo clave: los mejores jugadores de cada equipo en el mismo rol.

## 2B.9 Rivalidades
- Si dos equipos de la misma liga se enfrentan en 2 finales o playoffs seguidos, se marcan como **rivales** (ícono 🔥).
- En partidos entre rivales, ambos equipos suman +3 de moral si ganan y −3 si pierden (en vez de ±2).
- Noticia especial: *"Clásico: T1 vs Gen.G"*.
- Definir algunas rivalidades iniciales en el JSON (campo `rivales` del equipo).

---

# PARTE 2C — TORNEOS INTERNACIONALES, PREMIOS Y ASCENSOS

## 2C.1 Torneo Internacional de Mitad de Temporada (semanas 21–22)
- Participan los **campeones del Split 1** de cada región (solo Primera División).
- Formato: eliminación directa; si el número de equipos no es potencia de 2, los de mayor prestigio pasan directo a la siguiente ronda.
- Premio total: $500.000 (campeón 50%, finalista 25%, semifinalistas 12,5% cada uno).

## 2C.2 Mundial (semanas 43–46)
- Clasifican los **2 mejores** de cada región según la suma de puntos de ambos splits (en Counter-Strike 2 se llama **"Major"**).
- Fase de grupos (grupos de 4, todos contra todos, al mejor de 1) → los 2 mejores de cada grupo pasan a eliminación directa al mejor de 5.
- Premio total: $2.000.000 (campeón 40%, finalista 20%, semifinalistas 10% cada uno, cuartos de final 5% cada uno).

## 2C.3 Premios en dinero
- El premio va al **presupuesto del equipo**.
- Si un jugador que represento gana un torneo:
  - Recibe un bono (no afecta mi dinero), sube su moral +15 y su valor de mercado +10%.
  - Mi reputación sube: +2 (mitad de temporada) o +5 (Mundial).
  - Noticia destacada en dorado.

## 2C.4 Ascensos y descensos (semanas 47–52)
- El **último** de Primera División baja a Segunda.
- El **campeón** de Segunda División sube a Primera.
- Al subir: prestigio +8. Al bajar: prestigio −8.
- Recalcular presupuestos según el nuevo prestigio.

## 2C.5 Historial
- Guardar los campeones de cada liga y torneo por temporada.
- Pantalla **Palmarés**: lista de campeones por temporada, y en el detalle del equipo, sus títulos.

## 2C.6 Premios individuales de fin de temporada (semana 47)
Equivalentes a los premios del fútbol, entregados **por cada videojuego**:

| Premio | Equivalente en fútbol | Cómo se elige |
|---|---|---|
| **Jugador del Año** | Balón de Oro | Puntaje = nota promedio × 10 + títulos (Mundial 15, mitad de temporada 8, liga 5) + MVPs de serie × 0,5. Mínimo 20 series jugadas. |
| **Máximo Eliminador** | Bota de Oro | Más eliminaciones totales de la temporada (en Dota 2 y LoL solo cuentan los roles Carry/ADC/Mid). |
| **Revelación del Año** | Golden Boy | Mejor puntaje entre jugadores de 20 años o menos. |
| **Mejor Equipo Ideal** | Equipo del año | El mejor jugador de cada rol según nota promedio. |
| **Agente del Año** | — | El jugador humano lo gana si sus representados suman más títulos y premios que cualquier otro equipo; da reputación +5. |

- Ceremonia: pantalla especial con los ganadores, uno tras otro.
- Si gana uno de mis jugadores: valor +15%, moral +20, mi reputación +3.
- Guardar los premios en el historial del jugador y en el Palmarés.
- Mostrar en el detalle del jugador sus premios (ícono de trofeo).

---

# PARTE 2D — MERCADO VIVO (LOS DEMÁS EQUIPOS TAMBIÉN FICHAN)

## 2D.1 Ventanas de fichajes
- Solo se puede cerrar un traspaso **durante una ventana** (semanas 1–4, 23–26 y 47–52).
- Fuera de ventana, en el detalle del jugador mostrar: *"El mercado está cerrado. Próxima ventana: semana X."*
- Fichar a un **agente libre** se puede hacer en cualquier momento.

## 2D.2 Fichajes de la IA
Cada semana de ventana, cada equipo tiene un **25%** de probabilidad de intentar un fichaje:

1. Busca su **titular más débil** (menor habilidad).
2. Busca candidatos del mismo videojuego y rol, con al menos **+5 de habilidad** que ese titular, y cuyo valor de mercado entre en su presupuesto. Ordena a los candidatos por un **puntaje de fichaje**:
   ```
   puntaje = habilidad + (potencial − habilidad) × factorEdad + (forma − 3) × 3
   factorEdad: ≤ 21 → 0,6 · 22–25 → 0,3 · 26+ → 0
   ```
   Así los equipos grandes prefieren jugadores en buena forma y los equipos pequeños apuestan por jóvenes con potencial. Prioriza: agentes libres → jugadores de equipos de menor prestigio → jugadores de su misma región.
3. Elige al mejor candidato y hace una oferta:
   - Si el jugador **no es mío**: el traspaso se resuelve automáticamente (70% de éxito).
   - Si el jugador **es mío**: me llega una **oferta** para decidir (ver 2D.3).
4. El titular reemplazado pasa a ser **suplente** del equipo (cada equipo puede tener hasta 2 suplentes); si ya tiene 2, el más débil queda libre.
5. Máximo **2 fichajes por equipo por ventana**.
6. Crear noticias de los fichajes importantes (jugadores con habilidad ≥ 80 o equipos de prestigio ≥ 85).

## 2D.3 Ofertas por mis jugadores
- Nueva sección **Ofertas recibidas** (con un número rojo en la barra si hay pendientes).
- Cada oferta muestra: equipo, monto del traspaso, salario ofrecido y semanas para responder (2).
- Opciones: **Aceptar**, **Rechazar** o **Pedir más** (el equipo sube entre 5% y 15%, o se retira con 40% de probabilidad).
- Si no respondo a tiempo, la oferta vence.
- Al aceptar, gano mi comisión del 10% (igual que en la Fase 1).

## 2D.4 Suplentes y titulares
- Cada equipo: 5 titulares + hasta 2 suplentes.
- Al inicio de cada split, el equipo pone de titular al mejor jugador de cada rol.
- Un jugador suplente durante todo un split pierde −10 de moral.
- En el detalle del equipo, mostrar titulares y suplentes por separado.

## 2D.5 Renovaciones de contrato
- Cuando a uno de mis jugadores le quedan **8 semanas o menos** de contrato, su equipo puede ofrecer renovar (60% si su nota promedio es ≥ 6; 20% si es menor).
- Me llega como oferta: nuevo salario y duración. Puedo aceptar, rechazar (queda libre al terminar) o pedir más.
- Al renovar, gano una comisión del **5% del nuevo salario anual**.
- Jugadores que no son míos: los equipos renuevan automáticamente a sus titulares buenos; los demás quedan libres.

## 2D.6 Jóvenes talentos
- Al final de cada temporada se generan **3 jóvenes por región** de cada videojuego (en vez de 3 por videojuego), con potencial entre 60 y 95.
- Los equipos de Segunda División tienen 30% de probabilidad de fichar a un joven libre de su región en cada ventana.

---

# PARTE 2E — EVENTOS ALEATORIOS

## 2E.1 Funcionamiento general
- Archivo nuevo: `lib/logica/eventos.dart` con la lista de eventos y su lógica.
- Cada semana, **cada jugador que represento** tiene un **8%** de probabilidad de tener un evento.
- Además, cada semana hay un **15%** de probabilidad de un **evento de agencia** (afecta al agente, no a un jugador).
- Máximo **3 eventos por semana** para no saturar.
- Los eventos aparecen en una **ventana emergente** después de avanzar la semana, uno tras otro.
- Algunos eventos son **informativos** (solo botón "Entendido") y otros tienen **decisión** (dos opciones).
- Todo evento que cueste dinero muestra el costo y pide confirmación. **Nunca** cobrar más del 30% del dinero actual del agente en un evento.
- Cada evento se guarda como noticia.

Cada evento se define con: `id`, `titulo`, `descripcion` (puede usar `{nick}` para el nombre del jugador), `probabilidad relativa`, `condición` (ej: "edad ≤ 21"), `efectos` y, si tiene decisión, `opciones`.

## 2E.2 Eventos positivos de jugadores
| Evento | Condición | Efecto |
|---|---|---|
| **Despertar del talento**: "{nick} entrenó 12 horas diarias y descubrió un nuevo nivel." | edad ≤ 21 | potencial +3 a +8 (máx. 99) |
| **Partida perfecta**: "{nick} hizo una actuación histórica que se volvió viral." | tiene equipo | habilidad +2, moral +10, valor +10% |
| **Mentor veterano**: "Un exjugador profesional se ofrece a entrenar a {nick}." | edad ≤ 23 | **Decisión**: pagar 5% del valor del jugador → habilidad +3 y potencial +2 / rechazar |
| **Bootcamp en Corea**: "El equipo de {nick} organiza un bootcamp intensivo." | tiene equipo | habilidad +1 a +3 |
| **Cambio de rol exitoso**: "{nick} se adaptó perfectamente a una nueva posición." | — | habilidad +2 |
| **Streamer estrella**: "El stream de {nick} explotó en audiencia." | — | moral +15; agente gana $5.000–$20.000 en comisión |
| **Ídolo de su país**: "{nick} es portada de los medios de su país." | habilidad ≥ 75 | valor +8%, reputación del agente +1 |

## 2E.3 Eventos negativos de jugadores
| Evento | Condición | Efecto |
|---|---|---|
| **Tendinitis en la muñeca**: "{nick} sufre dolor en la muñeca." | — | no juega 2–6 semanas, habilidad −1 a −3 |
| **Burnout**: "{nick} está agotado mentalmente." | moral < 50 o edad ≥ 26 | **Decisión**: darle 3 semanas de descanso (no juega, moral +20) / que siga jugando (moral −15, 30% de perder habilidad −3) |
| **Polémica en redes**: "{nick} publicó un comentario que generó controversia." | — | **Decisión**: pagar un asesor de imagen (costo $10.000–$30.000, sin efectos) / ignorar (moral −10, valor −10%, reputación del agente −2) |
| **Bajón de forma**: "{nick} no encuentra su mejor nivel." | — | habilidad −2 a −4 |
| **Techo alcanzado**: "Los analistas creen que {nick} ya tocó su techo." | edad ≥ 22 | potencial baja hasta igualar la habilidad actual + 2 |
| **Problemas con el equipo**: "{nick} discutió con el entrenador." | tiene equipo | moral −20; 25% de que el equipo lo ponga en el mercado |
| **Conflicto con el agente**: "{nick} está molesto con tu gestión." | moral < 40 | **Decisión**: pagar un bono de $5.000–$15.000 (moral +20) / ignorar (40% de que deje la agencia) |

## 2E.4 Eventos neutrales o de decisión
| Evento | Efecto |
|---|---|
| **Oferta de otro videojuego**: "Un equipo de otro juego quiere probar a {nick}." | **Decisión**: cambiar de videojuego (habilidad × 0,75, potencial +5) / quedarse |
| **Oferta de marca de periféricos**: "Una marca quiere patrocinar a {nick}." | **Decisión**: aceptar (agente gana $10.000–$50.000, moral −5 por compromisos) / rechazar |
| **Invitación a un torneo de exhibición** | **Decisión**: participar (moral +10, 20% de lesión leve) / no participar |

## 2E.5 Eventos de agencia
| Evento | Efecto |
|---|---|
| **Artículo de prensa favorable** | reputación +2 |
| **Rumor negativo sobre tu agencia** | reputación −2 |
| **Inversor interesado**: "Un inversor quiere entrar a tu agencia." | **Decisión**: recibir $25.000–$100.000 a cambio de 10% de tus comisiones por 26 semanas / rechazar |
| **Auditoría fiscal** | pagar $2.000–$10.000 (sin decisión, pero con aviso claro) |
| **Contacto en un equipo grande** | durante 4 semanas, los equipos de prestigio ≥ 85 aceptan ofertas con 10% más de margen |
| **Fuga de información** | un equipo rival conoce tus jugadores: uno al azar recibe una oferta de traspaso inmediata |

## 2E.6 Eventos del mundo (solo noticias, sin decisión)
- Un jugador estrella (habilidad ≥ 85) de otro agente se lesiona o se retira.
- Un equipo cambia a su entrenador (moral de sus jugadores ±10).
- Una organización anuncia que entra a otro videojuego.
- Récord de audiencia en un torneo.

## 2E.7 Balance
- Poner todas las probabilidades y montos como **constantes** al inicio de `eventos.dart` para poder ajustarlos fácilmente.
- En **Ajustes**, agregar una opción: **Frecuencia de eventos**: Baja (×0,5), Normal (×1), Alta (×2).

---

## LISTA DE PRUEBAS DE LA FASE 2

### 2A
- [ ] Hay equipos de todas las regiones en los 4 videojuegos, con Primera y Segunda División.
- [ ] Puedo filtrar equipos por videojuego, región y división.
- [ ] Al editar un equipo en un archivo JSON y empezar una partida nueva, se ve el cambio.
- [ ] Las listas largas no se ponen lentas.

### 2B
- [ ] Al avanzar la semana se juegan partidos y se actualizan las tablas.
- [ ] Los jugadores tienen notas y estadísticas.
- [ ] Hay playoffs y campeones de cada liga.
- [ ] Los jugadores muestran su forma en estrellas y estadísticas (eliminaciones, KDA).
- [ ] La previsualización muestra probabilidades de victoria antes de cada partido.
- [ ] Los clásicos entre rivales aparecen marcados.

### 2C
- [ ] Se juega el Torneo de Mitad de Temporada y el Mundial con los clasificados correctos.
- [ ] Los premios aparecen en el presupuesto de los equipos.
- [ ] Al final de temporada hay ascensos y descensos.
- [ ] El Palmarés muestra los campeones.
- [ ] Al final de temporada hay ceremonia de premios (Jugador del Año, Máximo Eliminador, Revelación).

### 2D
- [ ] Fuera de ventana no puedo vender (salvo agentes libres).
- [ ] Otros equipos fichan y aparecen noticias de fichajes.
- [ ] Recibo ofertas por mis jugadores y puedo aceptar, rechazar o pedir más.
- [ ] Recibo ofertas de renovación.

### 2E
- [ ] Aparecen eventos al avanzar semanas, con ventana emergente.
- [ ] Los eventos con decisión funcionan en ambas opciones.
- [ ] Ningún evento me cobra más del 30% de mi dinero.
- [ ] La opción de frecuencia de eventos funciona.
