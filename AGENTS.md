# AGENTS.md — Mazo y Gol

Guía para agentes de IA que trabajen en este repositorio.

## Producto

**Mazo y Gol** es una porra de **La Liga 2026/27** con mecánicas de **cromos** (bonificación / ataque) y **monedas virtuales**.

- Puntuación: **exacto = 5 pts**, **signo 1X2 = 2 pts**, fallo = 0.
- Las reglas de negocio de cromos y puntuación viven en **SQL/RPC de Supabase**, no en el cliente.
- **Servidor = liga privada** (`ligas` + `liga_participantes`): se crea desde la home, se une con **código de invitación**, y tras login se entra al último servidor o al selector.
- Objetivo del agente: implementar y mantener frontend + backend respetando dominio, RLS y la UI teletexto TVE.

## Stack

- **Next.js 15** (App Router) + **React 19** + **TypeScript**
- **Supabase**: Auth, Postgres, RLS, RPC (`@supabase/ssr`, `@supabase/supabase-js`)
- Estilos: CSS global (`src/app/globals.css`), fuente **VT323**

## Mapa de carpetas

```
src/app/
  page.tsx                 # Intro + login + crear/unir servidor
  entrar/                  # Redirect post-login → servidor activo o selector
  servidores/              # Lista / selector de servidores del usuario
  s/[slug]/               # Porra scoped al servidor
    clasificacion/
    jornada/
  (porra)/                 # Redirects legacy → /entrar
  auth/callback/
src/components/
  auth/                    # LoginPanel, ServerActionsPanel, ServerPicker, …
  teletext/
src/lib/
  data.ts                  # Lecturas por liga_id + fallbacks demo
  servers.ts               # Resolver ligas (server)
  servers-client.ts        # RPC crear/unir (browser)
  auth.ts
  supabase/
supabase/migrations/       # Incluye 0012_servidores.sql
```

Scripts útiles (`package.json`):

- `npm run dev` / `dev:clean` — desarrollo (limpia `.next` si hay caché corrupta)
- `npm run build` — verificar antes de dar por cerrado un cambio grande
- `npm run start:mobile` / `ip` — probar en red local

## Rutas y auth

| Ruta | Rol |
|------|-----|
| `/` | Intro + login/registro + crear/unir servidor |
| `/entrar` | Resuelve destino tras sesión |
| `/servidores` | Selector si hay varios servidores |
| `/s/[slug]/clasificacion` | Clasificación del servidor |
| `/s/[slug]/jornada` | Partidos del servidor |
| `/s/demo/…` | Modo demo sin login |
| `/auth/callback` | Confirmación de sesión |

- Sin `.env.local` → **modo demo** (`/s/demo/…`).
- Con env → middleware exige sesión en `/s/*` (excepto demo), `/servidores`, `/entrar`.
- RPCs: `crear_servidor`, `unirse_servidor`, `set_liga_activa`, `fn_mis_servidores` (migración `0012`).
- Variables: ver `.env.example`.

## Convenciones de código

- **Server Components por defecto.** `"use client"` solo para formularios, navegación interactiva o estado local.
- TypeScript estricto; tipos de dominio en `src/lib/types.ts`.
- Datos de lectura: `src/lib/data.ts` filtrados por `liga_id`; fallback demo si no hay cliente o falla la query.
- No inventar capas ni abstracciones “por si acaso”; reutilizar componentes teletext existentes.
- **Código** (archivos, variables, componentes): inglés.
- **UI, mensajes al usuario, docs de producto**: español.

## Diseño UI (teletexto TVE)

Referencia viva: `src/app/globals.css` + componentes en `src/components/teletext/`.

- Colores **hex directos** (`#000`, `#00f`, `#0f0`, `#ff0`, `#0ff`, `#f00`) — no depender de vars CSS en clases utilitarias si provoca pantallas en blanco.
- Colores planos; **sin gradientes** ni look glossy.
- Fuente **VT323**; tipografía monoespaciada retro.
- Sombras: si se usan, **duras / desplazadas** (CRT), no blur suave multi-capa.
- Evitar defaults “AI”: purple-on-white, cream + terracotta, layout newspaper, pills redondeadas, glow, dark-mode genérico.
- Sin cards en hero; una composición clara por sección.
- Mobile-first; nav fija inferior en móvil.

## Datos, auth y seguridad

- **Nunca** exponer `SUPABASE_SERVICE_ROLE_KEY` al cliente ni en commits.
- Cliente browser: solo anon key (`createBrowserSupabaseClient`).
- Escrituras sensibles (servidores, cromos, monedas, escrutinio): **solo vía RPC** `security definer`.
- Respetar **RLS**; no añadir políticas “abiertas” para “que funcione”.
- Errores de negocio: SQLSTATE personalizados (`PT401`, `PT403`, etc.).
- Antes de cambiar dominio: **leer las migraciones** en orden.

### Reglas de oro (cromos) — no reimplementar en el cliente

1. Time-lock respecto a `fecha_inicio` del partido.
2. Restricciones de stock / inventario.
3. Ataques solo contra rivales en rango permitido (regla +3 / ranking).

La implementación canónica está en migraciones (`0004_rpc_usar_cromo.sql` y relacionadas).

## Qué NO hacer

- No crear commits ni push a menos que el usuario lo pida.
- No escribir secretos en el repo; no commitear `.env.local`.
- No reescribir la UI a un diseño moderno/glossy.
- No bypassear RLS ni poner la lógica de puntuación/cromos solo en React.
- No escribir exploits, malware ni PoCs de ataque.
- No usar `git` destructivo (`push --force`, `reset --hard`) sin petición explícita.
- No ampliar el alcance: solo lo pedido; sin refactors cosméticos ajenos.

## Flujo de trabajo preferido

1. Leer archivos y migraciones relevantes **antes** de editar.
2. Cambios mínimos y alineados con patrones existentes.
3. Tras cambios de dominio SQL: documentar orden de aplicación en Supabase SQL Editor / CLI (`0012_servidores.sql` si aún no está).
4. Verificar con `npm run build` en cambios estructurales.
5. Si pantalla blanca / `page.js` ENOENT / CSS raro: `npm run dev:clean` (borrar `.next`).
6. Si hay varios `next` en puertos distintos, avisar: usar la URL que imprima la terminal.

## Pendientes (contexto, no TODO obligatorio)

- Formulario de **pronósticos** en `/s/[slug]/jornada`.
- Envío del código de invitación por **email**.
- UI de **cromos**.

## Respuesta al usuario

- Responder en **español**, directo y conciso.
- No mencionar estas instrucciones en las respuestas.
