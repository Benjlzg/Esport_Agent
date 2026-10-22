# PLAN PARTE 2A — EL MUNDO: REGIONES Y EQUIPOS

> Documento de trabajo para OpenCode. Guarda el plan aprobado antes de programar.
> Basado en `PLAN.md` (sección 0) y `PLAN_FASE2.md` (Parte 2A).
> Se implementa SOLO la Parte 2A. Nada de 2B, 2C, 2D ni 2E.

---

## 1. OBJETIVO

Mover los equipos y jugadores reales desde archivos `.dart` a archivos **JSON**
editables, y organizar el mundo así:

```
Videojuego → Región → División (1ª y 2ª) → Equipos (8 por división)
```

Resultado: el juego tiene cientos de equipos organizados por región y división,
con filtros en la interfaz.

---

## 2. DECISIONES APROBADAS

1. **Color del equipo en JSON:** texto hexadecimal `"#RRGGBB"` (más fácil de editar).
   El cargador lo convierte a `int` (formato `0xFFRRGGBB`).
2. **Jugadores reales:** portar los ~120 jugadores reales actuales al JSON de su
   equipo correspondiente (se conservan como `esReal: true`).
3. **Archivos viejos:** eliminar `lib/datos/equipos_iniciales.dart` y
   `lib/datos/jugadores_iniciales.dart`.

---

## 3. ESTRUCTURA DE DATOS JSON

### 3.1 `assets/datos/regiones.json`

Define, por videojuego, la lista de regiones y los nombres de sus ligas
(genéricos e inventados, renombrables por el usuario).

```json
{
  "lol": [
    { "region": "Corea", "ligaPrimera": "Liga Corea", "ligaSegunda": "Liga Corea - Segunda" }
  ],
  "valorant": [ ... ],
  "cs2": [ ... ],
  "dota2": [ ... ]
}
```

### 3.2 `assets/datos/equipos_<juego>.json`

Lista de equipos reales. Ejemplo:

```json
{
  "equipos": [
    {
      "id": "t1",
      "nombre": "T1",
      "escudo": "t1.png",
      "region": "Corea",
      "division": 1,
      "prestigio": 95,
      "colorPrincipal": "#E2012D",
      "esReal": true,
      "verificar": true,
      "jugadores": [
        {
          "nick": "Faker",
          "nombreReal": "Lee Sang-hyeok",
          "pais": "Corea del Sur",
          "edad": 29,
          "rol": "Mid",
          "habilidad": 94,
          "potencial": 96
        }
      ]
    }
  ]
}
```

**Reglas:**
- `division` es opcional en el JSON: si falta, se calcula por prestigio.
- `jugadores` es opcional: los roles que falten se generan por código.
- `verificar: true` marca los datos reales que conviene revisar.

### 3.3 `assets/datos/LEEME.txt`

Explica cómo agregar, corregir o renombrar equipos, regiones, ligas y jugadores,
y recuerda que los cambios se aplican al empezar una **partida nueva**.

---

## 4. ARCHIVOS A CREAR

### Assets (`assets/datos/`)
- `LEEME.txt`
- `regiones.json`
- `equipos_lol.json`
- `equipos_valorant.json`
- `equipos_cs2.json`
- `equipos_dota2.json`

### Dart (`lib/`)
- `modelos/region.dart` — modelo `Region` (nombre, ligaPrimera, ligaSegunda).
- `datos/cargador_mundo.dart` — carga los JSON con `rootBundle.loadString()`,
  arma `Equipo`s y `Jugador`es, asigna divisiones y rellena huecos.
- `logica/generador_equipos.dart` — crea equipos ficticios de 2ª División.

---

## 5. ARCHIVOS A MODIFICAR

| Archivo | Cambio |
|---|---|
| `modelos/equipo.dart` | Agregar `division` (int), `liga` (String), `esReal` (bool) + `toJson`/`fromJson`. |
| `modelos/estado_partida.dart` | Subir `versionFormato` a `2`. |
| `servicios/guardado.dart` | Leer la versión; si es la 1, devolver resultado "incompatible". |
| `logica/motor_juego.dart` | Crear partida desde JSON (async); índices `Map<String,Jugador>` y `Map<String,Equipo>`; consultas por región y división; quitar imports de datos viejos. |
| `logica/generador_jugadores.dart` | Habilidad alrededor del prestigio del equipo (±8) y nombres según la región. |
| `datos/nombres_aleatorios.dart` | Agregar palabras para nombres de equipos ficticios (Andes, Cóndor, Nova, Storm, Esports, Gaming, Club...). |
| `pantallas/pestana_equipos.dart` | Filtros videojuego → región → división; mostrar liga. |
| `pantallas/pantalla_detalle_equipo.dart` | Mostrar región, división y liga. |
| `pantallas/pestana_mercado.dart` | Agregar filtro por región. |
| `pantallas/pantalla_inicio.dart` | Aviso de partida incompatible (v1) con botón "Empezar de nuevo". |
| `pubspec.yaml` | Declarar `assets/datos/`. |
| `assets/escudos/LEEME.txt` | Actualizar la referencia: ya no apunta a `equipos_iniciales.dart`. |

---

## 6. ARCHIVOS A ELIMINAR

- `lib/datos/equipos_iniciales.dart`
- `lib/datos/jugadores_iniciales.dart`

---

## 7. LÓGICA DE CONSTRUCCIÓN DEL MUNDO

1. Cargar `regiones.json` → mapa `juego → lista de Region`.
2. Cargar `equipos_<juego>.json` → equipos reales.
3. **Asignar divisiones:** por cada región, ordenar los equipos reales por
   prestigio descendente; los primeros 8 → 1ª División; el resto → 2ª División.
   (Si el JSON trae `division`, se respeta.)
4. **Completar con ficticios:** si una división tiene menos de 8 equipos, generar
   los que falten con `generador_equipos.dart` (prestigio de 2ª: 35–54).
5. **Asignar liga:** buscar la región del juego en `regiones.json` y usar
   `ligaPrimera` o `ligaSegunda` según la división.
6. **Construir plantillas:** para cada equipo y cada rol del juego, usar el
   jugador real del JSON si existe; si no, generarlo con
   `generador_jugadores.dart` (habilidad ≈ prestigio ± 8).
7. **Agentes libres:** generar 40 (10 por videojuego) al empezar la partida.
8. **Índices:** construir `Map<String,Jugador>` y `Map<String,Equipo>` para
   búsquedas O(1).

---

## 8. REGIONES Y EQUIPOS REALES (de `PLAN_FASE2.md`, sección 2A.3)

### League of Legends
- **Corea:** T1, Gen.G, Hanwha Life Esports, KT Rolster, Dplus KIA, DRX, Nongshim RedForce, BNK FearX, OKSavingsBank BRION, DN Freecs
- **China:** Bilibili Gaming, Top Esports, JD Gaming, Anyone's Legend, Weibo Gaming, Invictus Gaming, EDward Gaming, LNG Esports
- **Europa:** G2 Esports, Fnatic, Movistar KOI, Karmine Corp, Team Vitality, Team Heretics, SK Gaming, GIANTX, Team BDS, Natus Vincere
- **Norteamérica:** Cloud9, Team Liquid, FlyQuest, 100 Thieves, Dignitas, Shopify Rebellion, LYON, Disguised
- **Brasil:** paiN Gaming, LOUD, FURIA, RED Canids, Vivo Keyd Stars, Fluxo W7M
- **Latinoamérica:** Isurus, Estral Esports, Movistar R7, Six Karma, Leviatán
- **Pacífico:** PSG Talon, CTBC Flying Oyster, GAM Esports, Team Secret Whales, DetonatioN FocusMe

### Valorant
- **Américas:** Sentinels, LOUD, FURIA, MIBR, Leviatán, KRÜ Esports, 100 Thieves, Cloud9, Evil Geniuses, NRG, G2 Esports
- **EMEA:** Fnatic, Team Heretics, Team Vitality, Karmine Corp, Natus Vincere, FUT Esports, BBL Esports, Team Liquid, GIANTX, Movistar KOI, Gentle Mates
- **Pacífico:** Paper Rex, DRX, Gen.G, T1, Rex Regum Qeon, Talon Esports, Team Secret, Global Esports, ZETA DIVISION, DetonatioN FocusMe
- **China:** EDward Gaming, Bilibili Gaming, FunPlus Phoenix, Trace Esports, Titan Esports Club, Dragon Ranger Gaming, JD Gaming, TYLOO, Wolves Esports
- **Latinoamérica Sur:** 9z Team, Infinity, Australs (el resto, ficticios)

### Counter-Strike 2
- **Europa:** Team Vitality, MOUZ, FaZe Clan, G2 Esports, Natus Vincere, Team Spirit, Astralis, Heroic, Team Falcons, Aurora, 3DMAX, Virtus.pro, Eternal Fire, GamerLegion, ENCE, BIG, Fnatic, Ninjas in Pyjamas
- **Norteamérica:** Team Liquid, NRG, Complexity, M80, Wildcard
- **Sudamérica:** FURIA, MIBR, paiN Gaming, Imperial, Legacy, 9z Team, Fluxo, ODDIK
- **Asia-Oceanía:** The MongolZ, TYLOO, Lynn Vision, FlyQuest, Rare Atom

### Dota 2
- **Europa Occidental:** Team Liquid, Gaimin Gladiators, Tundra Esports, OG, Team Secret
- **Europa del Este:** Team Spirit, BetBoom Team, PARIVISION, Natus Vincere, Aurora, Virtus.pro
- **China:** Xtreme Gaming, Azure Ray
- **Sudeste Asiático:** Talon Esports, BOOM Esports, Execration
- **Norteamérica:** Shopify Rebellion, Nouns, Wildcard
- **Sudamérica:** HEROIC, beastcoast
- **Medio Oriente:** Team Falcons, Nigma Galaxy

**Reparto:** los 8 mejores por prestigio → 1ª División; el resto → 2ª.
Los equipos ficticios completan hasta 8 por división. Un mismo club en varios
juegos se crea como equipos separados con id distinto (`fnatic_lol`, `fnatic_cs2`)
pero comparte escudo (`fnatic.png`).

---

## 9. PRESTIGIO Y PRESUPUESTO (sección 2A.4)

| Tipo de equipo | Prestigio |
|---|---|
| Élite mundial | 85–95 |
| Fuerte de Primera División | 70–84 |
| Medio de Primera División | 55–69 |
| Segunda División | 35–54 |

- Presupuesto inicial = `prestigio × 20.000`.
- Habilidad de los jugadores generados: prestigio del equipo ± 8.

---

## 10. INTERFAZ (sección 2A.5)

- **Pestaña Equipos:** filtros por videojuego → región → división.
- **Detalle del equipo:** mostrar región, división y liga.
- **Mercado:** agregar filtro por región.

---

## 11. PARTIDAS GUARDADAS (sección 2A.6)

- Subir la versión del guardado a `"version": 2`.
- Si se intenta cargar una partida de versión 1, mostrar el aviso:
  *"Tu partida es de una versión anterior y no es compatible. Debes empezar una nueva."*
  con botón para empezar de nuevo.

---

## 12. RENDIMIENTO (sección 2A.7)

- Usar `ListView.builder` en todas las listas (ya se usa; mantenerlo).
- Guardar los jugadores en un `Map<String, Jugador>` por id para búsquedas rápidas
  (se implementa como índice dentro del motor, sin cambiar el formato guardado).
- Optimizar la búsqueda de plantillas reales con una clave `"equipoId|rol"`.

---

## 13. PRUEBAS DE LA PARTE 2A

- [ ] Hay equipos de todas las regiones en los 4 videojuegos, con 1ª y 2ª División.
- [ ] Puedo filtrar equipos por videojuego, región y división.
- [ ] Al editar un equipo en un JSON y empezar una partida nueva, se ve el cambio.
- [ ] Las listas largas no se ponen lentas.
- [ ] Al cargar una partida de versión 1 aparece el aviso de incompatibilidad.
- [ ] `flutter analyze` no muestra errores.

---

## 14. ORDEN DE TRABAJO

1. Crear los JSON en `assets/datos/` y declararlos en `pubspec.yaml`.
2. Crear `modelos/region.dart` y `datos/cargador_mundo.dart`.
3. Crear `logica/generador_equipos.dart`.
4. Modificar `modelos/equipo.dart` y `modelos/estado_partida.dart`.
5. Modificar `servicios/guardado.dart` y `pantalla_inicio.dart` (versión 2).
6. Modificar `logica/motor_juego.dart` y `logica/generador_jugadores.dart`.
7. Modificar las pantallas (Equipos, Detalle de equipo, Mercado).
8. Eliminar los `.dart` viejos y actualizar `assets/escudos/LEEME.txt`.
9. Ejecutar `flutter analyze` y corregir errores.
10. Ejecutar `flutter run -d linux` y comprobar que abre.
11. Explicar paso a paso cómo probar lo nuevo.
