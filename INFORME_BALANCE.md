# INFORME DE BALANCE — FASE 2.5

Generado por `test/balance_test.dart`.

- Semilla: **20251019**.
- Partida: agente observador con 1.000.000.000 de dinero, sin reclutar.
- Los eventos se resuelven solos eligiendo la opción más barata.
- Comando: `flutter test test/balance_test.dart --tags lento --run-skipped`. La suite normal (`flutter test`) salta estas pruebas.

## Ajustes de constantes

| Ronda | Constante | Antes | Después | Motivo |
| --- | --- | --- | --- | --- |
| 1 | multiplicadorValorMaximo | 5,0 | 3,0 | El valor máximo llegaba a 6,3 M, por encima del presupuesto máximo de un equipo. Se acota para evitar valores absurdos y mantener el mercado viable. |
| 1 | probProgresoJoven | 0,30 | 0,22 | Intentar reducir el salto de habilidad de 3,09 entre T1 y T2. El resultado empeoró (3,29), así que se revirtió en la ronda 2. |
| 2 | probProgresoJoven | 0,22 | 0,30 | Revertir la ronda 1: la reducción de la progresión juvenil no mejoró el salto de habilidad entre temporadas. |
| 2 | ajusteHabilidadReemplazo | 0 (constante nueva) | -2 | Los reemplazos por bajas se generaban al prestigio del equipo y elevaban la media. Con -2 el salto máximo baja a 2,68 y la habilidad se estabiliza. |


Se hicieron 2 de las 3 rondas permitidas. No quedó ningún ajuste pendiente de constantes.

### Correcciones de lógica

- Al vencer el contrato de un titular, su equipo repone el rol en la misma semana. Sin esto, las plantillas se vaciaban con las temporadas y desde T2 había equipos sin 5 titulares.

## Economía, valores y títulos

| Temporada | Presup. inicio | Presup. fin | Fin / inicio | Valor máx. | Valor P95 | Equipo con más títulos | Títulos | % del total |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 415.080.000 | 158.526.000 | 0.38× | 2.157.000 | 1.447.000 | t1_lol | 4 | 4.0 % |
| 2 | 415.080.000 | 154.406.000 | 0.37× | 3.783.000 | 1.991.000 | fnatic_valorant | 4 | 4.0 % |
| 3 | 415.080.000 | 149.942.000 | 0.36× | 3.783.000 | 2.166.000 | team_spirit_dota2 | 4 | 4.0 % |
| 4 | 415.080.000 | 177.510.000 | 0.43× | 3.783.000 | 2.148.000 | t1_lol | 3 | 3.0 % |
| 5 | 415.080.000 | 171.972.000 | 0.41× | 3.783.000 | 2.004.000 | team_spirit_dota2 | 4 | 4.0 % |
| 6 | 415.080.000 | 152.594.000 | 0.37× | 3.558.000 | 1.908.000 | t1_lol | 3 | 3.0 % |
| 7 | 415.080.000 | 165.918.000 | 0.40× | 3.783.000 | 1.737.000 | t1_lol | 3 | 3.0 % |
| 8 | 415.080.000 | 143.992.000 | 0.35× | 3.783.000 | 1.689.000 | t1_lol | 4 | 4.0 % |
| 9 | 415.080.000 | 144.383.000 | 0.35× | 3.492.000 | 1.635.000 | t1_lol | 4 | 4.0 % |
| 10 | 415.080.000 | 139.936.000 | 0.34× | 3.783.000 | 1.569.000 | giantx_valorant | 3 | 3.0 % |


## Habilidad promedio por videojuego (jugadores con equipo)

| Temporada | LoL | Valorant | CS2 | Dota 2 | Media |
| --- | --- | --- | --- | --- | --- |
| 1 | 60.9 | 65.4 | 66.5 | 56.4 | 62.3 |
| 2 | 63.6 | 68.1 | 69.4 | 58.9 | 65.0 |
| 3 | 65.1 | 69.3 | 70.4 | 60.6 | 66.3 |
| 4 | 66.2 | 69.0 | 71.0 | 61.0 | 66.8 |
| 5 | 66.3 | 70.1 | 71.4 | 62.4 | 67.5 |
| 6 | 67.0 | 69.7 | 72.2 | 62.6 | 67.8 |
| 7 | 67.3 | 70.3 | 71.6 | 62.3 | 67.9 |
| 8 | 66.7 | 69.3 | 70.8 | 62.2 | 67.2 |
| 9 | 66.9 | 69.4 | 70.2 | 62.7 | 67.3 |
| 10 | 66.0 | 69.5 | 71.0 | 62.8 | 67.3 |


## Mercado y eventos

| Temporada | Fichajes IA V1 (1–4) | Fichajes IA V2 (23–26) | Fichajes IA V3 (47–52) | Fichajes IA total | Ofertas IA | Eventos | Eventos con decisión |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 243 | 232 | 247 | 722 | 0 | 14 | 1 |
| 2 | 258 | 216 | 233 | 707 | 0 | 7 | 0 |
| 3 | 225 | 202 | 243 | 670 | 0 | 12 | 1 |
| 4 | 207 | 187 | 222 | 616 | 0 | 14 | 0 |
| 5 | 229 | 178 | 217 | 624 | 0 | 11 | 0 |
| 6 | 209 | 194 | 227 | 630 | 0 | 12 | 0 |
| 7 | 237 | 174 | 200 | 611 | 0 | 9 | 1 |
| 8 | 220 | 181 | 219 | 620 | 0 | 17 | 1 |
| 9 | 238 | 181 | 216 | 635 | 0 | 9 | 0 |
| 10 | 212 | 177 | 224 | 613 | 0 | 15 | 1 |


## Tiempos

| Temporada | Tiempo total | Media por semana |
| --- | --- | --- |
| 1 | 4047 ms | 77.8 ms |
| 2 | 3899 ms | 75.0 ms |
| 3 | 5104 ms | 98.2 ms |
| 4 | 5846 ms | 112.4 ms |
| 5 | 5847 ms | 112.4 ms |
| 6 | 6453 ms | 124.1 ms |
| 7 | 6708 ms | 129.0 ms |
| 8 | 7831 ms | 150.6 ms |
| 9 | 8108 ms | 155.9 ms |
| 10 | 8543 ms | 164.3 ms |


- Semanas medidas: 520.
- Tiempo total de avance: 62852 ms.
- Media global por semana: 118.5 ms.

## Invariantes

Sin violaciones duras en las 10 temporadas.

## Veredicto

- Violaciones duras: **0**.
- Mayor salto de habilidad entre temporadas: 2.68 puntos (orientativo ≤ 3).
- Mayor porcentaje de títulos de un equipo en una temporada: 4.0 % (orientativo ≤ 50 %).
- Mayor relación presupuesto fin / inicio: 0.43×.
- Fichajes IA registrados en las ventanas: 6448.
- Robot de 3 temporadas: sobrevivió, racha máxima sin opciones 5 semanas.

<!-- ROBOT:INICIO -->
## Jugador robot (3 temporadas)

- Recluta agentes libres con habilidad ≤ reputación + 40, potencial alto (≥ habilidad + 10) y coste ≤ 25 % del dinero; máximo 8 representados.
- Vende en ventana pidiendo el valor de mercado y acepta contraofertas ≥ 90 %.
- Responde eventos con la opción más barata y acepta traspasos ≥ 92 % del valor; las renovaciones solo si el salario no baja.

| Temporada | Dinero inicio | Dinero fin | Reput. inicio | Reput. fin | Decisiones | Fichajes | Ventas | Eventos | Ofertas | Semanas sin opción | Racha máx. |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 1.000.000.000 | 1.000.301.600 | 10 | 29 | 16 | 8 | 19 | 32 | 7 | 11 | 5 |
| 2 | 1.000.301.600 | 1.000.703.334 | 29 | 39 | 15 | 0 | 16 | 41 | 3 | 0 | 0 |
| 3 | 1.000.703.334 | 1.001.327.712 | 39 | 43 | 20 | 0 | 18 | 43 | 6 | 0 | 0 |


### Decisiones por tipo

| Evento | Veces |
| --- | --- |
| marca_perifericos | 17 |
| oferta_otro_juego | 9 |
| torneo_exhibicion | 6 |
| polemica_redes | 6 |
| mentor_veterano | 4 |
| burnout | 4 |
| conflicto_agente | 3 |
| inversor_interesado | 2 |


### Veredicto del robot

- Quiebra: **no**.
- Eventos respondidos: 116 (51 con decisión).
- Fichajes propios: 8 · ventas: 53.
- Semanas sin ninguna opción: 11 · racha máxima: 5 (preocupante desde 8).
- Racha preocupante: **no**.
- Tiempo del robot: 17275 ms.

<!-- ROBOT:FIN -->
