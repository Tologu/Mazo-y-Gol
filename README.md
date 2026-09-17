# Mazo y Gol

Porra privada de La Liga. Puedes montar un servidor con tus colegas, meter pronósticos cada jornada y, si juegas en modo Mazo y Gol, usar cromos y monedas.

Hecho con Next.js y Supabase. La interfaz va al estilo teletexto.

## Local

```bash
npm install
```

Copia `.env.example` a `.env.local` y rellena las claves de Supabase. Luego:

```bash
npm run dev
```

Sin `.env.local` abre en modo demo.

Las migraciones están en `supabase/migrations/`. Hay que aplicarlas en el proyecto de Supabase (SQL Editor o CLI) en orden.

## Scripts

- `npm run dev` — desarrollo
- `npm run build` — build de producción
- `npm run start:mobile` — preview en la red local
