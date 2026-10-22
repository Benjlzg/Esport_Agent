# PLAN PARTE 2D — MERCADO VIVO

> Documento de trabajo para OpenCode. Basado en `PLAN.md` (sección 0) y
> `PLAN_FASE2.md` (Parte 2D). Se implementa SOLO la Parte 2D. Nada de 2E.
> Las reglas de la sección 0 de `PLAN.md` siguen vigentes (paquetes, comentarios
> en español, confirmaciones, `flutter analyze`, etc.).

---

## 1. OBJETIVO

Que el mercado se mueva aunque yo no haga nada:

- **Ventanas de fichajes** (semanas 1–4, 23–26 y 47–52).
- **Fichajes de la IA:** los demás equipos fichan solos.
- **Ofertas por mis jugadores:** puedo aceptar, rechazar o pedir más.
- **Suplentes y titulares:** cada equipo tiene 5 titulares y hasta 2 suplentes.
- **Renovaciones de contrato:** los equipos ofrecen renovar a mis jugadores.
- **Jóvenes talentos por región** al final de cada temporada.

Hoy los traspasos se cierran en cualquier momento, no existe la IA de fichajes,
no hay ofertas entrantes, ni suplentes, ni renovaciones, ni jóvenes por región.

---

## 2. DECISIONES APROBADAS

1. **Versión del guardado → `5`.** `versionMinimaCompatible` sigue en `3`: las
   partidas v3 y v4 se cargan y se actualizan a la 5 (los campos nuevos tienen
   valores por defecto tolerantes).
2. **Suplentes:** campo `bool suplente` en `Jugador` (por defecto `false`).
   **Titulares** = jugadores con el mismo `equipoId` y `!suplente`. El poder de
   equipo, la simulación y las plantillas de juego usan solo **titulares**.
3. **Región del jugador:** campo `String? region` en `Jugador` (por defecto
   `null`). Se rellena al generar jóvenes/libres. Es necesario para 2D.6
   ("joven libre de su región"). Compatible hacia atrás.
4. **Ventanas de fichajes:** semanas `1–4`, `23–26` y `47–52`. Fuera de ventana
   no se puede cerrar un traspaso de un jugador **con equipo**; los **agentes
   libres** sí se pueden fichar en cualquier momento.
5. **Ofertas:** un solo modelo `Oferta` con
   `enum TipoOferta { traspaso, renovacion }`, guardadas en
   `EstadoPartida.ofertas`. Se responde en **2 semanas**; si no respondo, vence.
6. **Fichajes de la IA:** máximo **2 por equipo por ventana**, con un contador
   `fichajesVentana` (`Map<String,int>` por `equipoId`) que se **resetea al
   empezar cada ventana**.
7. **Al cerrar un traspaso** (mío o de la IA) el jugador desplazado en ese rol
   baja a **suplente** (si el equipo ya tiene 2 suplentes, el más débil queda
   libre), en vez de quedar libre directamente.
8. **Ofertas recibidas — dónde verlas:** ícono con **badge rojo** en la barra
   superior que abre `pantalla_ofertas.dart`. Además, **acceso directo** desde
   `pestana_mis_jugadores.dart`.
9. **Fichaje IA de un jugador ajeno que deja un rol vacío** en el equipo de
   origen: se genera un **reemplazo ficticio** acorde al prestigio de ese equipo
   para mantener 5 titulares.

---

## 3. MODELOS

### 3.1 `lib/modelos/oferta.dart` (nuevo)

- `enum TipoOferta { traspaso, renovacion }`.
- `Oferta`:
  - `id` (String, único).
  - `tipo` (`TipoOferta`).
  - `jugadorId` (String).
  - `equipoId` (String) — el equipo que hace la oferta.
  - `monto` (int) — traspaso: precio ofrecido; renovación: nuevo salario anual.
  - `salarioAnual` (int) — traspaso: salario ofrecido al jugador; renovación:
    igual que `monto`.
  - `semanasRestantes` (int) — empieza en 2 para traspaso; en renovación se
    mantiene mientras el contrato siga vigente.
  - `temporada`, `semana` (int) — cuándo se generó.
- `toJson()` / `fromJson()`.

### 3.2 `lib/modelos/jugador.dart` (modificar)

- Nuevo campo `bool suplente` (default `false`).
- Nuevo campo `String? region` (default `null`).
- `toJson()` los incluye; `fromJson()` los lee de forma tolerante
  (`as bool? ?? false`, `as String?`) para no romper partidas antiguas.

### 3.3 `lib/modelos/estado_partida.dart` (modificar)

- Nuevos campos:
  - `List<Oferta> ofertas` (default `[]`).
  - `Map<String,int> fichajesVentana` (default `{}`).
- `versionFormato` sube a **5**; `versionMinimaCompatible` se mantiene en **3**.
- Serialización tolerante a campos ausentes.

### 3.4 `lib/modelos/equipo.dart`

- Sin cambios de estructura (los suplentes se derivan de `Jugador.suplente`).

---

## 4. LÓGICA

### 4.1 `lib/logica/calendario.dart` (modificar)

- Constante con las ventanas de fichajes.
- `bool enVentanaFichajes(int semana)` → verdadero en 1–4, 23–26 y 47–52.
- `String proximaVentanaTexto(int semana)` → texto del tipo
  *"Próxima ventana: semana 23"* (si ya estamos en ventana, vacío).

### 4.2 `lib/logica/formulas.dart` (modificar)

Constantes comentadas y ajustables para el balance:

- Probabilidad de que un equipo intente un fichaje por semana de ventana (25 %).
- Máximo de fichajes por equipo y ventana (2).
- Diferencia mínima de habilidad sobre el titular más débil (+5).
- Factores de edad del puntaje de fichaje (≤21 → 0,6 · 22–25 → 0,3 · 26+ → 0).
- Probabilidad de éxito del traspaso automático de la IA (70 %).
- Rango de subida al "pedir más" (5 %–15 %) y probabilidad de retirada (40 %).
- Probabilidades de renovación (60 % con nota ≥ 6 · 20 % si menor).
- Comisión por renovación (5 % del nuevo salario anual).
- Castigo de moral por ser suplente todo un split (−10).
- Máximo de suplentes por equipo (2).
- Umbral de contrato para ofrecer renovación (8 semanas).

### 4.3 `lib/logica/mercado.dart` (nuevo)

- `double puntajeFichaje(Jugador j)`:
  ```
  puntaje = habilidad + (potencial − habilidad) × factorEdad + (forma − 3) × 3
  ```
- `Jugador? titularMasDebil(Equipo, List<Jugador>)`.
- `List<Jugador> candidatosPara(Equipo, ...)`:
  - mismo videojuego y rol, con al menos +5 de habilidad sobre el titular
    más débil del equipo, y `valorMercado <= presupuesto`.
  - Ordena por `puntajeFichaje`.
  - Prioriza: **agentes libres → jugadores de equipos de menor prestigio →
    jugadores de su misma región**.
- `void procesarMercadoIA(...)`:
  - Por cada equipo, 25 % por semana de ventana (respetando el máximo de 2
    fichajes por ventana).
  - Elige el mejor candidato y resuelve:
    - **No es mío:** traspaso automático con 70 % de éxito; el desplazado baja
      a suplente; si el equipo de origen queda con un rol vacío, se genera un
      reemplazo ficticio.
    - **Es mío:** crea una `Oferta` de traspaso (no se cierra sola).
  - Noticias de fichajes importantes (habilidad ≥ 80 o prestigio ≥ 85).

### 4.4 `lib/logica/renovaciones.dart` (nuevo)

- A mis jugadores con **≤ 8 semanas** de contrato: su equipo ofrece renovar con
  60 % de probabilidad (nota promedio ≥ 6) o 20 % si es menor. Se crea una
  `Oferta` de renovación (nuevo salario y duración).
- Al aceptar: nuevo salario, `semanasContrato = 52 + azar(0..52)` y comisión del
  **5 % del nuevo salario anual**.
- Al rechazar: el jugador quedará libre al terminar su contrato.
- **Jugadores ajenos:** el equipo renueva automáticamente a sus titulares buenos
  (nota ≥ 6 o habilidad alta); los demás quedan libres al llegar a 0.

### 4.5 `lib/logica/simulador_partidos.dart` y `pantalla_previa_partido.dart`

- `poderEquipo` y `simularEnfrentamiento` filtran **titulares** (`!suplente`).
- La previa (poder, forma y duelo clave) usa titulares.

### 4.6 `lib/logica/generador_jugadores.dart` (modificar)

- Nuevo `generarJovenDeRegion(rnd, id, juego, region)`: usa el perfil de nombres
  de la región y genera un joven con **potencial entre 60 y 95**, asignando
  `region`.

### 4.7 `lib/logica/motor_juego.dart` (modificar)

- `avanzarSemana` (orden):
  1. `_simularEtapaActual()` (ya existe).
  2. Si `enVentanaFichajes(semana)`: `procesarMercadoIA(...)` + renovaciones.
  3. Bajar `semanasRestantes` de las ofertas y **expirar** a 0 (noticia).
  4. Al inicio de split (semana 5 y 27): `reorganizarTitulares(...)`.
  5. Contratos, progreso, semana, temporada, dinero y bancarrota (ya existe).
- `_cerrarTrato`: el jugador desplazado en ese rol pasa a **suplente**; si el
  equipo supera el máximo de suplentes, el más débil queda libre.
- `reorganizarTitulares(...)`: por cada rol, el mejor jugador es titular y el
  resto suplentes; recorta suplentes sobrantes.
- `_nuevaTemporada`:
  - Genera **3 jóvenes por región** de cada videojuego (potencial 60–95).
  - Resetea `fichajesVentana`.
  - Los equipos de 2ª División tienen 30 % de fichar un joven libre de su región.
- Acciones nuevas: `aceptarOferta`, `rechazarOferta`, `pedirMasOferta`.
- Getters: `ofertasPendientes`, `ofertasDe`, `titularesDe`, `suplentesDe`.

---

## 5. INTERFAZ

- **Nuevo `lib/pantallas/pantalla_ofertas.dart`:** lista de ofertas pendientes
  (equipo, monto, salario y semanas restantes) con **Aceptar**, **Rechazar** y
  **Pedir más**.
- `lib/pantallas/pantalla_principal.dart`: **badge rojo** con el número de
  ofertas pendientes en la barra superior; abre `pantalla_ofertas.dart`.
- `lib/pantallas/pantalla_detalle_jugador.dart`:
  - Bloquear "Ofrecer a un equipo" fuera de ventana (salvo agentes libres) con
    *"El mercado está cerrado. Próxima ventana: semana X."*
  - Etiqueta **Titular** / **Suplente** cuando tiene equipo.
- `lib/pantallas/pantalla_negociacion.dart`: mismo bloqueo por ventana.
- `lib/pantallas/pantalla_detalle_equipo.dart`: separar **Titulares** y
  **Suplentes**.
- `lib/pantallas/pestana_mis_jugadores.dart`: acceso directo a las ofertas
  pendientes.
- `lib/widgets/tarjeta_jugador.dart` (opcional): marca de suplente.

---

## 6. DATOS

- `assets/datos/LEEME.txt`: nota breve sobre las ventanas de fichajes y los
  suplentes. **No** hay cambios en los JSON.

---

## 7. ARCHIVOS A CREAR

- `PLAN_2D.md` (este documento)
- `lib/modelos/oferta.dart`
- `lib/logica/mercado.dart`
- `lib/logica/renovaciones.dart`
- `lib/pantallas/pantalla_ofertas.dart`
- `test/mercado_test.dart`

## 8. ARCHIVOS A MODIFICAR

| Archivo | Cambio |
|---|---|
| `lib/modelos/jugador.dart` | `suplente`, `region` y serialización. |
| `lib/modelos/estado_partida.dart` | `ofertas`, `fichajesVentana`; versión 5. |
| `lib/logica/calendario.dart` | `enVentanaFichajes`, `proximaVentanaTexto`. |
| `lib/logica/formulas.dart` | Constantes del mercado 2D. |
| `lib/logica/generador_jugadores.dart` | `generarJovenDeRegion`. |
| `lib/logica/simulador_partidos.dart` | Plantillas con titulares. |
| `lib/logica/motor_juego.dart` | Mercado IA, renovaciones, ofertas, titulares, jóvenes. |
| `lib/pantallas/pantalla_principal.dart` | Badge de ofertas. |
| `lib/pantallas/pantalla_detalle_jugador.dart` | Bloqueo por ventana + titular/suplente. |
| `lib/pantallas/pantalla_negociacion.dart` | Bloqueo por ventana. |
| `lib/pantallas/pantalla_detalle_equipo.dart` | Titulares y suplentes. |
| `lib/pantallas/pantalla_previa_partido.dart` | Usar titulares. |
| `lib/pantallas/pestana_mis_jugadores.dart` | Acceso a ofertas. |
| `assets/datos/LEEME.txt` | Nota de ventanas/suplentes. |
| `PROGRESO.md` | Sección 2D con guía de prueba. |

---

## 9. ORDEN DE TRABAJO

1. Crear `lib/modelos/oferta.dart`.
2. Añadir `suplente` y `region` a `lib/modelos/jugador.dart` (+ serialización).
3. Ampliar `lib/modelos/estado_partida.dart` (`ofertas`, `fichajesVentana`) y
   subir `versionFormato` a **5**.
4. Añadir `enVentanaFichajes` / `proximaVentanaTexto` a
   `lib/logica/calendario.dart`.
5. Añadir las constantes 2D a `lib/logica/formulas.dart`.
6. Crear `lib/logica/mercado.dart` (puntaje, candidatos, fichajes IA y ofertas).
7. Crear `lib/logica/renovaciones.dart`.
8. Añadir `generarJovenDeRegion` a `lib/logica/generador_jugadores.dart`.
9. Adaptar `lib/logica/simulador_partidos.dart` y
   `lib/pantallas/pantalla_previa_partido.dart` para usar titulares.
10. Integrar todo en `lib/logica/motor_juego.dart` (ventana, mercado IA,
    renovaciones, expiración de ofertas, reorganizar titulares, acciones y
    getters, `_nuevaTemporada`).
11. Crear `lib/pantallas/pantalla_ofertas.dart`.
12. Modificar `lib/pantallas/pantalla_principal.dart` (badge + acceso).
13. Modificar `lib/pantallas/pantalla_detalle_jugador.dart` y
    `pantalla_negociacion.dart` (bloqueo por ventana + etiqueta titular/suplente).
14. Modificar `lib/pantallas/pantalla_detalle_equipo.dart` (Titulares/Suplentes).
15. Modificar `lib/pantallas/pestana_mis_jugadores.dart` (acceso a ofertas).
16. Actualizar `assets/datos/LEEME.txt`.
17. `flutter analyze` y `flutter test`; añadir `test/mercado_test.dart`
    (ventanas, puntaje de fichaje y expiración de ofertas). Corregir todo.
18. `flutter run -d linux` para comprobar que la app abre.
19. Añadir la sección 2D a `PROGRESO.md` con la guía de prueba paso a paso.

---

## 10. PRUEBAS DE LA PARTE 2D

- [ ] Fuera de ventana no puedo vender (salvo agentes libres).
- [ ] Otros equipos fichan y aparecen noticias de fichajes.
- [ ] Recibo ofertas por mis jugadores y puedo aceptar, rechazar o pedir más.
- [ ] Recibo ofertas de renovación.
- [ ] Cada equipo muestra titulares y suplentes por separado.
- [ ] Al final de temporada se generan jóvenes por región.
- [ ] `flutter analyze` no muestra errores.
