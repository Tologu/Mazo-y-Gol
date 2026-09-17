# Mazo y Gol

Porra de La Liga 2026/27. Un servidor es una liga privada (`ligas` + `liga_participantes`). Se crea desde la home o se entra con código. Tras el login va al último servidor o al selector.

Puntos: exacto 5, signo 1X2 2, fallo 0. Los cromos y el escrutinio van en SQL/RPC de Supabase, no en React.

## Stack

Next.js 15 (App Router), React 19, TypeScript, Supabase (Auth, Postgres, RLS). Estilos en `src/app/globals.css`, fuente VT323.

## Carpetas

```
src/app/page.tsx          intro + login + crear/unir servidor
src/app/entrar/           post-login
src/app/servidores/       selector
src/app/s/[slug]/         porra de ese servidor
src/components/teletext/  UI teletexto
src/lib/data.ts           lecturas por liga_id
supabase/migrations/
```

`npm run dev` / `dev:clean` / `build`. Sin `.env.local` cae a demo (`/s/demo`).

## Código

Inglés en archivos y variables. Español en la UI. Server Components por defecto; `"use client"` solo si hace falta. Tipos en `src/lib/types.ts`. Escrituras sensibles solo por RPC. No commitear `.env.local` ni la service role.

Cromos: time-lock del partido, stock del inventario, un jugador solo recibe 1 ataque por jornada, tienda de 3 cartas distinta por jugador y día (00:00 Madrid). Eso está en las migraciones, no lo reimplementes en el cliente.

## UI

Colores hex planos (`#000`, `#00f`, `#0f0`…). Sin gradientes. Sombras duras si las hay. Nav abajo en móvil.
