# CORRECCIONES DE LA FASE 2.5

> Resultado de revisar `INFORME_BALANCE.md` y las capturas de `capturas/`.
> Las reglas de la sección 0 de `PLAN.md` siguen vigentes. Mantener el formato de
> guardado compatible (si hace falta un campo nuevo, con valor por defecto, como en 2C–2E).
> No implementar nada de la Fase 3.

---

## A. ERRORES (prioridad alta)

### A1. El evento de patrocinio se muestra como un costo
En la captura del evento "Oferta de patrocinio", el botón dice
"Aceptar el patrocinio ($1.000)" y aparece el aviso "Los costos ya están limitados al
30 % de tu dinero actual". Según `PLAN_2E.md`, aceptar debe **pagar** al agente entre
$10.000 y $50.000 (y bajar la moral −5).
- Revisar `marca_perifericos` y cualquier otro evento que **dé** dinero
  (`streamer_estrella`, `inversor_interesado`): un ingreso nunca debe pasar por
  `limitarCostoEvento` ni pedir confirmación de gasto.
- En el botón, mostrar los ingresos como "+$25.000" y los costos como "−$10.000".
- El aviso del 30 % solo debe aparecer si alguna opción del evento **cuesta** dinero.
- Agregar una prueba en `test/eventos_test.dart`: aceptar el patrocinio aumenta el dinero.

### A2. Truco de ventas repetidas
El robot hizo 53 ventas con solo 8 jugadores: vende al mismo jugador en cada ventana
y cobra comisión cada vez.
- Un jugador que acaba de ser traspasado (por mí o por la IA) **no puede volver a ser
  ofrecido ni vendido hasta la temporada siguiente**. Campo nuevo en `Jugador`, por
  ejemplo `temporadaUltimoTraspaso` (por defecto `null`, compatible con partidas viejas).
- En el detalle del jugador, si está bloqueado, mostrar:
  "Recién fichado: podrá cambiar de equipo la próxima temporada."
- Los equipos de la IA tampoco lo pueden comprar en ese periodo.
- Agregar una prueba que lo verifique.

### A3. El juego se vuelve más lento con las temporadas
La media por semana sube de 78 ms (T1) a 164 ms (T10). Algo crece sin límite.
- Medir qué listas crecen cada temporada (noticias, resultados guardados, jugadores
  retirados, ofertas vencidas, eventos resueltos, etc.) y anotarlo en el informe.
- Límites propuestos:
  - Noticias: guardar como máximo las de las **2 últimas temporadas**.
  - Resultados de partidos: guardar solo los de la temporada actual (el palmarés y los
    premios ya conservan la historia importante).
  - Jugadores retirados que no son míos ni tienen premios: eliminarlos al cambiar de
    temporada.
  - Ofertas vencidas y eventos ya resueltos: eliminarlos.
- Evitar recorrer todos los jugadores del mundo varias veces por semana cuando se pueda
  usar los índices que ya existen.
- Agregar al informe el **tamaño del archivo de guardado** (en KB) al final de cada
  temporada.
- Meta: que la semana de la temporada 10 no tarde más de 1,5 veces lo que tarda la de la
  temporada 1.

---

## B. BALANCE

### B1. Repetir el robot con la economía real
El robot empezó con $1.000.000.000, así que nunca se probó la economía del jugador.
- Ejecutar el robot de 3 temporadas empezando con **$50.000 y reputación 10**, igual
  que un jugador nuevo.
- Mantener también la versión actual del robot rico solo si es útil para otra métrica;
  si no, reemplazarla.
- Anotar en el informe: dinero al final de cada temporada, si quebró, en qué semana tuvo
  menos dinero y cuál fue su principal fuente de ingresos.
- Criterio orientativo: el robot no debe quebrar, pero tampoco debe tener más de
  $5.000.000 al final de la temporada 3. Si gana demasiado o quiebra, ajustar las
  constantes (máximo 3 rondas, anotando antes y después).

### B2. Eventos repetidos
`marca_perifericos` salió 17 veces de 51 decisiones.
- Agregar un tiempo de espera por evento: el mismo evento no puede repetirse para el
  mismo jugador en **26 semanas**, ni el mismo evento de agencia en **12 semanas**.
- Bajar el peso de `marca_perifericos` de 10 a 6.

### B3. Medir el dominio por liga
La métrica "% del total de títulos" mezcla todas las ligas del mundo y siempre sale baja.
- Reemplazarla por: para cada liga de 1ª División, cuántas veces ganó el mismo equipo en
  10 temporadas. Reportar las 5 ligas con un campeón más repetido.
- Criterio orientativo: ningún equipo debería ganar su liga más de 6 de 10 temporadas.
  Si pasa, anotarlo y proponer un ajuste (no aplicarlo sin anotarlo).

### B4. Solo anotar (se resuelve en la Fase 4)
El presupuesto de los equipos se reinicia cada temporada, así que los premios y las ventas
no se acumulan. **No cambiarlo ahora**; anotarlo en `PROGRESO.md` como pendiente de la
Fase 4 (economía).

---

## C. INTERFAZ (según las capturas)

1. **"Calendario" se corta en dos líneas** en el selector de Competición. Usar textos
   más cortos, quitar los íconos del `SegmentedButton` o achicar la letra, de modo que
   ningún segmento se parta.
2. **El botón "Avanzar semana" tapa el último elemento** de las listas (Mercado, Equipos,
   Mi agencia, Resumen, Calendario). Agregar espacio al final de cada lista (unos 100 px)
   para que el último elemento quede visible sobre el botón.
3. **Los filtros de videojuego se cortan** ("Dota" sin el "2"). Usar `Wrap` para que
   bajen a una segunda línea, o textos que quepan en el ancho de un celular.
4. **El trofeo de la ceremonia sale como un cuadro con una X.** No usar emojis en la
   interfaz; reemplazarlos por íconos de Material (ej: `Icons.emoji_events` para 🏆,
   `Icons.local_fire_department` para 🔥). Revisar todas las pantallas.
5. **La pestaña Ligas aparece vacía al entrar.** Elegir por defecto el primer videojuego,
   la primera región y la 1ª División.
6. **El escudo de Dplus KIA (negro) no se ve sobre el fondo oscuro.** Agregar a los
   círculos de iniciales un borde fino gris claro.
7. **Al ofrecer un jugador, el precio pedido aparece vacío.** Rellenarlo con el valor de
   mercado sugerido y, si hay equipos interesados, preseleccionar el primero.
8. **Ofertas:** el plan de la 2D dice 2 semanas para responder, pero la captura muestra 3.
   Revisar si es un error o si cuenta la semana actual; dejarlo coherente con el texto.

---

## D. AL TERMINAR

1. `flutter analyze` sin errores y `flutter test` en verde.
2. Ejecutar las pruebas lentas (`flutter test --tags lento`) y actualizar
   `INFORME_BALANCE.md` con los resultados nuevos (robot con $50.000, tiempos, tamaño
   del guardado y dominio por liga).
3. Regenerar las capturas: `flutter test test/golden_test.dart --update-goldens`.
4. Actualizar `PROGRESO.md` con lo hecho y lo pendiente.
