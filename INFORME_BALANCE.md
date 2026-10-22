# INFORME DE BALANCE — FASE 2.5

- Generado: **2026-10-21 23:04:28** (hora local).
- Generado por: `test/balance_test.dart`.

- Semilla: **20251019**.
- Partida observadora (10 temporadas): agente con 1.000.000.000 de dinero, sin reclutar.
- Los eventos se resuelven solos eligiendo la opción más barata.
- Comando: `flutter test test/balance_test.dart --tags lento --run-skipped`. La suite normal (`flutter test`) salta estas pruebas.

## Ajustes de constantes

| Ronda | Constante | Antes | Después | Motivo |
| --- | --- | --- | --- | --- |
| 1 | multiplicadorValorMaximo | 5,0 | 3,0 | El valor máximo llegaba a 6,3 M, por encima del presupuesto máximo de un equipo. Se acota para evitar valores absurdos y mantener el mercado viable. |
| 1 | probProgresoJoven | 0,30 | 0,22 | Intentar reducir el salto de habilidad de 3,09 entre T1 y T2. El resultado empeoró (3,29), así que se revirtió en la ronda 2. |
| 2 | probProgresoJoven | 0,22 | 0,30 | Revertir la ronda 1: la reducción de la progresión juvenil no mejoró el salto de habilidad entre temporadas. |
| 2 | ajusteHabilidadReemplazo | 0 (constante nueva) | -2 | Los reemplazos por bajas se generaban al prestigio del equipo y elevaban la media. Con -2 el salto máximo baja a 2,68 y la habilidad se estabiliza. |


Las rondas 1–2 de la tabla son de la fase anterior. En esta ejecución se hicieron 3 rondas para corregir la progresión juvenil y el salto T1 → T2, anotadas abajo.

### Ajustes de esta ejecución (3 rondas)

| Ronda | Cambio | Antes | Después | Resultado |
| --- | --- | --- | --- | --- |
| 1 | progresión juvenil | 30 % semanal para todos los ≤ 23 años | 10 % (16–19), 9 % (20–21), 5 % (22–23); sin equipo ×0,5 y suplente ×0,85 | Subida media 4,2 puntos/temporada, pero el salto T1 → T2 subió a 3,17 (límite 3). |
| 2 | progresión juvenil | 10 / 9 / 5 % | 11 / 10 / 5,5 % | Subida 4,4, salto 3,19 y el robot llegó a 8 semanas sin opciones (preocupante). Se revirtió en la ronda 3. |
| 3 | progresión + reemplazos | 11 / 10 / 5,5 % · reemplazos -2 | 10 / 9 / 5 % · reemplazos -3 | Subida 4,2; salto T1 → T2 2,69; robot con racha máxima 5. Cumplen progresión y estabilidad. |


- **Dominio por liga (B3):** sigue por encima del criterio (17 ligas con un campeón en más de 6 de 10 temporadas). La propia corrección B3 pide medirlo y proponer un ajuste sin aplicarlo; además depende de la economía de la Fase 4 (B4), así que queda anotado como pendiente.

### Correcciones de lógica

- Al vencer el contrato de un titular, su equipo repone el rol en la misma semana. Sin esto, las plantillas se vaciaban con las temporadas y desde T2 había equipos sin 5 titulares.

## Economía y valores

| Temporada | Presup. inicio | Presup. fin | Fin / inicio | Valor máx. | Valor P95 |
| --- | --- | --- | --- | --- | --- |
| 1 | 415.080.000 | 184.305.000 | 0.44× | 2.157.000 | 1.166.000 |
| 2 | 415.080.000 | 169.646.000 | 0.41× | 3.783.000 | 1.650.000 |
| 3 | 415.080.000 | 177.266.000 | 0.43× | 3.783.000 | 2.055.000 |
| 4 | 415.080.000 | 180.690.000 | 0.44× | 3.492.000 | 2.133.000 |
| 5 | 415.080.000 | 196.765.000 | 0.47× | 3.783.000 | 2.133.000 |
| 6 | 415.080.000 | 182.807.000 | 0.44× | 3.492.000 | 2.127.000 |
| 7 | 415.080.000 | 167.699.000 | 0.40× | 3.492.000 | 2.115.000 |
| 8 | 415.080.000 | 182.296.000 | 0.44× | 3.783.000 | 2.115.000 |
| 9 | 415.080.000 | 160.568.000 | 0.39× | 3.783.000 | 2.064.000 |
| 10 | 415.080.000 | 163.826.000 | 0.39× | 3.783.000 | 2.118.000 |


## Habilidad promedio por videojuego (jugadores con equipo)

| Temporada | LoL | Valorant | CS2 | Dota 2 | Media |
| --- | --- | --- | --- | --- | --- |
| 1 | 58.1 | 62.5 | 63.7 | 53.5 | 59.4 |
| 2 | 61.0 | 65.1 | 66.1 | 56.3 | 62.1 |
| 3 | 63.0 | 65.7 | 67.2 | 57.0 | 63.2 |
| 4 | 63.4 | 66.3 | 67.5 | 58.1 | 63.8 |
| 5 | 62.8 | 66.6 | 68.1 | 60.0 | 64.4 |
| 6 | 63.6 | 66.9 | 67.7 | 59.0 | 64.3 |
| 7 | 64.0 | 66.6 | 68.1 | 59.0 | 64.4 |
| 8 | 63.6 | 66.2 | 68.3 | 59.8 | 64.5 |
| 9 | 63.6 | 66.5 | 67.9 | 60.2 | 64.6 |
| 10 | 63.7 | 66.6 | 67.8 | 60.1 | 64.6 |


## Progresión de jóvenes (16–21 años)

Se compara la habilidad al inicio y al final de cada temporada de los jugadores que tenían entre 16 y 21 años al empezar (solo los que siguen en la partida). Objetivo: un joven con equipo debe subir entre **4 y 8 puntos por temporada**. Sin equipo la probabilidad de mejorar es la mitad; los suplentes mejoran un poco menos que los titulares.

Los promedios por situación excluyen a los jugadores que ya estaban en su potencial al empezar (no podían subir). La columna **Media todos** los incluye para que la medición sea transparente.

| Temporada | Con equipo | Sin equipo | Titulares | Suplentes | Media todos | Medidos | En su potencial |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 5.9 | 6.7 | 5.9 | 0.0 | 5.9 | 810 | 0 |
| 2 | 4.2 | 6.0 | 4.1 | 4.6 | 3.2 | 953 | 257 |
| 3 | 3.8 | 3.7 | 3.7 | 4.0 | 2.2 | 1059 | 446 |
| 4 | 3.9 | 4.0 | 3.9 | 3.7 | 2.1 | 1025 | 468 |
| 5 | 3.6 | 3.6 | 3.7 | 3.5 | 2.1 | 987 | 426 |
| 6 | 4.0 | 3.6 | 3.9 | 4.1 | 2.5 | 828 | 289 |
| 7 | 4.1 | 4.0 | 4.2 | 3.8 | 2.6 | 839 | 298 |
| 8 | 4.0 | 4.3 | 4.0 | 3.9 | 2.7 | 798 | 272 |
| 9 | 4.2 | 4.0 | 4.2 | 4.1 | 2.7 | 800 | 284 |
| 10 | 4.0 | 4.1 | 4.0 | 4.2 | 2.6 | 790 | 285 |


- Progresión media con equipo (con margen de mejora): **4.2 puntos/temporada** · sin equipo: **4.4**.
- La regla ×0,5 para jugadores sin equipo se aplica por jugador y está cubierta por `test/progresion_test.dart`; la media observada sin equipo puede variar por la mezcla de edades y de potencial.
- Jugadores medidos en 10 temporadas: 8889 · ya estaban en su potencial: 3025.
- Criterio 4–8 puntos por temporada: **cumple**.

## Dominio por liga (1ª División, 10 temporadas)

Para cada liga de 1ª División se cuentan las temporadas distintas en las que el mismo equipo ganó al menos un split. Se muestran las 5 ligas con un campeón más repetido. Criterio orientativo: ningún equipo debería ganar su liga más de 6 de 10 temporadas.

| Liga | Equipo | Temporadas ganadas | Títulos de split |
| --- | --- | --- | --- |
| Circuito de Asia y Oceanía · CS2 · Asia-Oceanía | the_mongolz_cs2 | 10 de 10 | 20 |
| Liga China · Dota 2 · China | xtreme_gaming_dota2 | 10 de 10 | 19 |
| Circuito Norteamericano · CS2 · Norteamérica | team_liquid_cs2 | 10 de 10 | 18 |
| Liga del Sudeste Asiático · Dota 2 · Sudeste Asiático | talon_esports_dota2 | 10 de 10 | 17 |
| Liga de Europa del Este · Dota 2 · Europa del Este | team_spirit_dota2 | 10 de 10 | 16 |


- Ligas con un campeón por encima de 6 de 10 temporadas: **17**.
- Ajuste propuesto (no aplicado): repartir mejor los títulos reduciendo el determinismo de las series (menor `factorProbabilidad`) o añadiendo desgaste a los campeones. Se anota para una ronda futura.

## Mercado y eventos

| Temporada | Fichajes IA V1 (1–4) | Fichajes IA V2 (23–26) | Fichajes IA V3 (47–52) | Fichajes IA total | Ofertas IA | Eventos | Eventos con decisión |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 251 | 209 | 277 | 737 | 0 | 9 | 1 |
| 2 | 241 | 213 | 281 | 735 | 0 | 18 | 1 |
| 3 | 228 | 213 | 262 | 703 | 0 | 11 | 1 |
| 4 | 228 | 214 | 254 | 696 | 0 | 7 | 0 |
| 5 | 214 | 200 | 220 | 634 | 0 | 18 | 1 |
| 6 | 218 | 200 | 256 | 674 | 0 | 13 | 1 |
| 7 | 250 | 210 | 226 | 686 | 0 | 8 | 1 |
| 8 | 211 | 212 | 244 | 667 | 0 | 15 | 1 |
| 9 | 250 | 218 | 239 | 707 | 0 | 9 | 2 |
| 10 | 229 | 198 | 248 | 675 | 0 | 12 | 0 |


## Tiempos

| Temporada | Tiempo total | Media por semana |
| --- | --- | --- |
| 1 | 5664 ms | 108.9 ms |
| 2 | 8020 ms | 154.2 ms |
| 3 | 7920 ms | 152.3 ms |
| 4 | 7709 ms | 148.3 ms |
| 5 | 7939 ms | 152.7 ms |
| 6 | 7699 ms | 148.1 ms |
| 7 | 7573 ms | 145.6 ms |
| 8 | 7352 ms | 141.4 ms |
| 9 | 7305 ms | 140.5 ms |
| 10 | 7204 ms | 138.5 ms |


- Semanas medidas: 520.
- Tiempo total de avance: 74840 ms.
- Media global por semana: 139.1 ms.

## Tamaño de los datos (corrección A3)

Se miden al final de cada temporada, antes de la limpieza de inicio de temporada. La limpieza conserva 2 temporadas de noticias, vacía los resultados al empezar la temporada y limita los agentes libres a 300.

| Temporada | Jugadores | Noticias | Resultados | Palmarés | Premios | Ofertas | Eventos | Guardado (KB) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 2552 | 200 | 5456 | 100 | 16 | 0 | 0 | 2848.4 |
| 2 | 2716 | 200 | 5456 | 200 | 32 | 0 | 0 | 3461.6 |
| 3 | 2752 | 200 | 5456 | 300 | 48 | 0 | 0 | 3478.0 |
| 4 | 2769 | 200 | 5456 | 400 | 64 | 0 | 0 | 3517.9 |
| 5 | 2710 | 200 | 5456 | 500 | 80 | 0 | 0 | 3498.0 |
| 6 | 2750 | 200 | 5456 | 600 | 96 | 0 | 0 | 3522.9 |
| 7 | 2730 | 200 | 5456 | 700 | 112 | 0 | 0 | 3534.3 |
| 8 | 2722 | 200 | 5456 | 800 | 128 | 0 | 0 | 3540.5 |
| 9 | 2758 | 200 | 5456 | 900 | 144 | 0 | 0 | 3532.6 |
| 10 | 2715 | 200 | 5456 | 1000 | 160 | 0 | 0 | 3592.7 |


## Invariantes

Sin violaciones duras en las 10 temporadas.

## Veredicto

- Violaciones duras: **0**.
- Mayor salto de habilidad entre temporadas: 2.69 puntos (orientativo ≤ 3).
- Progresión media de 16–21 años con equipo: 4.2 puntos/temporada (objetivo 4–8; sin equipo 4.4).
- Mayor dominio en una liga de 1ª División: 10 de 10 temporadas del mismo equipo (orientativo ≤ 6): **no cumple**. Se deja anotado para la Fase 4 por indicación de B3/B4.
- Mayor relación presupuesto fin / inicio: 0.47×.
- Tiempo de la temporada 10 / temporada 1: 1.27× (meta ≤ 1,5×).
- Tamaño final del guardado: 3592.7 KB.
- Fichajes IA registrados en las ventanas: 6914.
- Robot de 3 temporadas: sobrevivió, racha máxima sin opciones 5 semanas.

<!-- ROBOT:INICIO -->
## Jugador robot (3 temporadas)

- Economía real: empieza con $50.000 y reputación 10, igual que un jugador nuevo (B1).
- Recluta agentes libres con habilidad ≤ reputación + 40, potencial alto (≥ habilidad + 10) y coste ≤ 25 % del dinero; máximo 8 representados.
- Vende en ventana pidiendo el valor de mercado y acepta contraofertas ≥ 90 %.
- Responde eventos con la opción más barata y acepta traspasos ≥ 92 % del valor; las renovaciones solo si el salario no baja.

| Temporada | Dinero inicio | Dinero fin | Reput. inicio | Reput. fin | Decisiones | Fichajes | Ventas | Eventos | Ofertas | Semanas sin opción | Racha máx. |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 50.000 | 209.725 | 10 | 19 | 13 | 8 | 9 | 32 | 0 | 10 | 5 |
| 2 | 209.725 | 371.464 | 19 | 19 | 11 | 0 | 8 | 34 | 1 | 0 | 0 |
| 3 | 371.464 | 627.916 | 19 | 17 | 15 | 1 | 8 | 42 | 1 | 0 | 0 |


### Dinero e ingresos

- Semana con menos dinero: antes de la primera semana ($50.000).
- Principal fuente de ingresos: Eventos ($486.877).
- Criterio B1 (sin quiebra y ≤ $5.000.000 al final de la T3): **cumple** (dinero final $627.916).

| Fuente de ingreso | Total |
| --- | --- |
| Comisiones de salario | 15.878 |
| Traspasos | 228.870 |
| Renovaciones | 675 |
| Eventos | 486.877 |


### Decisiones por tipo

| Evento | Veces |
| --- | --- |
| torneo_exhibicion | 9 |
| polemica_redes | 8 |
| mentor_veterano | 7 |
| marca_perifericos | 5 |
| oferta_otro_juego | 3 |
| burnout | 3 |
| inversor_interesado | 3 |
| conflicto_agente | 1 |


### Veredicto del robot

- Quiebra: **no**.
- Eventos respondidos: 108 (39 con decisión).
- Fichajes propios: 9 · ventas: 25.
- Semanas sin ninguna opción: 10 · racha máxima: 5 (preocupante desde 8).
- Racha preocupante: **no**.
- Tiempo del robot: 27691 ms.

<!-- ROBOT:FIN -->
