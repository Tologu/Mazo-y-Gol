# NOTAS — Mazo y Gol

Apuntes de solicitudes de producto y cambios acordados (conversación agente / usuario).

---

## 1. Nombres en la clasificación de la porra

- Los jugadores salían como **«Jugador»** en vez del nombre registrado (ej. **SPECIAL ONE**).
- Usar el campo **Nombre** del registro, **no** el **Usuario** (username interno).
- El **Nombre** es obligatorio al registrarse y es lo que se muestra en clasificación.

**Implementado:** registro corregido, sync de perfil desde Auth, migraciones SQL `0015` y `0016`.

---

## 2. Sección «Mi Usuario»

- Pestaña **Mi Usuario** dentro de cada servidor (`/s/[slug]/cuenta`).
- Permite **cambiar el nombre** visible en la clasificación.
- Usuario y correo: solo lectura.

---



## 3. Eliminar modo invitado / demo

- Quitar **«Explorar sin login»** y el flujo demo/invitado.
- Sin Supabase configurado → no hay acceso anónimo a porras.
- La home solo muestra **Iniciar sesión** y **Registrarse**.

---



## 4. Crear / unir servidor en «Servidores»

- **Quitar** crear servidor y unirse con código de la **página principal**.
- Tras login, esas opciones están en la pestaña **Servidores** (`/servidores`).
- Con servidores existentes: lista + crear/unir en la misma pantalla.

---



## 5. Tras login → «Servidores»

- Al iniciar sesión, **siempre** ir a **Servidores** (no entrar directo al último servidor).
- Desde ahí se elige porra, se crea una nueva o se une con código.

---



## 6. Jornada — clasificación de equipos (La Liga)

- En **Jornada**, desplegable con **clasificación de equipos** según **resultados oficiales** registrados en la app (PJ, G, E, P, GF, GC, Pts).
- **Colores por posición** (estilo teletexto):
  - **1–4** verde
  - **5–6** amarillo
  - **7** naranja
  - **3 últimos** rojo
  - resto blanco/cian

---



## 7. Ver pronósticos de otros jugadores

- En la **clasificación de la porra**, pulsar un participante para ver sus pronósticos de la jornada (informativo).
- **Reglas:**
  - Solo se exigen los partidos **aún abiertos** a pronósticos.
  - Partidos **bloqueados** (time-lock), **finalizados** o **suspendidos** cuentan como rellenados (entrada tardía).
  - Quien mira debe tener completos los suyos **abiertos**; si no, no puede ver los de otros.
- RPC: `fn_pronosticos_jugador` (migración `0018`; incluye/sustituye `0017`).

---

## 8. Admin manual vs API en directo

- **Decisión:** el **admin de la liga** registra resultados (panel Admin + RPC escrutinio).
- Una API externa podría usarse más adelante como **asistente** (precargar marcadores), no como fuente única.
- Motivos: servidores privados, coste/API, mapeo de nombres ficticios, control de errores.

---

## 9. Suspender partidos (Admin)

- En **Admin**, botón **Suspender** por partido (aplazamiento / suspensión real).
- Estado `suspendido`: sin puntos, no exige pronóstico, etiqueta `[SUSPENDIDO]`.
- Después, el owner puede meter el marcador real con **Resultado** / **Guardar** (`registrar_resultado_liga`).
- RPC: `suspender_partido_liga` (migración `0018`).

---

## 10. Incidencias técnicas conocidas

| Problema | Solución |
|----------|----------|
| Error `vendor-chunks/@supabase.js` / pantalla rota | Parar dev, borrar `.next`, `npm run dev:clean` |
| Build: `next/headers` en Client Component | `nombreVisible` en `@/lib/nombre-visible.ts`, no importar `@/lib/perfil` desde cliente |
| `Could not find function fn_pronosticos_jugador` | Aplicar **`0018_pronosticos_cerrados_suspender.sql`** en SQL Editor |

---

## Migraciones SQL — orden en Supabase

1. `0012_servidores.sql` (si falta)
2. `0013_simulacion.sql`
3. `0014_perfiles_pronosticos.sql`
4. `0015_nombres_clasificacion.sql`
5. `0016_clasificacion_solo_nombre.sql`
6. `0017_pronosticos_ajenos.sql` (opcional si aplicas 0018)
7. **`0018_pronosticos_cerrados_suspender.sql`** — completitud con partidos cerrados + suspender
8. `0019_pronostico_partido_suspendido.sql`
9. **`0020_reiniciar_resultados_jornada.sql`** — admin: borrar resultados+puntos de una jornada
10. **`0021_jornadas_2_38_partidos.sql`** — calendario jornadas 2–38 + fecha única 12:00 Madrid + backfill
11. **`0022_cierre_pronosticos_vie_mar.sql`** — cierre pronósticos: viernes 12:00 (finde) / martes 12:00 (J2, J6, J33)
12. **`0023_modo_juego.sql`** — modos `clasica` | `mazo_y_gol` al crear servidor; gate `usar_cromo`
13. **`0024_apertura_secuencial_jornadas.sql`** — jornada N se abre al cerrar la N-1; solo una abierta a la vez
14. **`0025_renombrar_equipos.sql`** — Levante Granota, Málaga Blanquiazul, Rojiblanco Madrid

---

## Sesión (login)

- La sesión caduca **8 horas** después del último inicio de sesión (`last_sign_in_at`).
- Lo aplica el middleware en rutas protegidas y `getSessionUser`.
- En el plan Pro de Supabase se puede duplicar en Auth → Sessions → Time-box (28800 s).

---

## Pendiente / pospuesto

- Recuperación de contraseña por email (PKCE, redirect, rate limit Supabase).
- UI de **cromos**.
- Envío de código de invitación por email.

---

## Rutas relevantes

| Ruta | Uso |
|------|-----|
| `/` | Solo login / registro |
| `/servidores` | Lista, crear y unirse a servidores |
| `/s/[slug]/clasificacion?jornada=N` | Clasificación porra + ver pronósticos ajenos |
| `/s/[slug]/jornada?jornada=N` | Partidos, clasificación equipos, mis pronósticos |
| `/s/[slug]/cuenta` | Mi Usuario (cambiar nombre) |
| `/s/[slug]/admin?jornada=N` | Simulación / resultados / suspender / reiniciar (solo owner) |


