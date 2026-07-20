-- =====================================================================
-- 0001_core.sql
-- Núcleo del dominio: perfiles, liga, jornadas, partidos y pronósticos.
-- Base de datos: PostgreSQL (Supabase). Todas las fechas en UTC (timestamptz).
-- =====================================================================

create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "citext";      -- usernames case-insensitive

-- ---------------------------------------------------------------------
-- ENUMS
-- ---------------------------------------------------------------------

-- Estado del ciclo de vida de una jornada.
create type estado_jornada as enum (
  'borrador',     -- se está montando, no visible
  'abierta',      -- admite pronósticos y uso de cromos
  'en_juego',     -- algún partido ya empezó; bloqueada para cromos según time-lock
  'cerrada',      -- todos los partidos terminaron, pendiente de escrutinio
  'escrutada'     -- puntos calculados y aplicados
);

-- Estado de un partido concreto (la verdad del time-lock se calcula con fecha_inicio,
-- este campo es un cache para UI/escrutinio).
create type estado_partido as enum (
  'programado',
  'en_juego',
  'finalizado',
  'suspendido'
);

-- ---------------------------------------------------------------------
-- PERFILES  (extiende auth.users de Supabase)
-- ---------------------------------------------------------------------
create table public.perfiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  username      citext unique not null,
  nombre        text not null,
  avatar_url    text,
  es_admin      boolean not null default false,
  -- Saldo de monedas virtuales. Se mantiene sincronizado vía ledger (ver 0002).
  -- nunca debe quedar negativo.
  monedas       bigint not null default 0 check (monedas >= 0),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.perfiles is 'Perfil público de cada usuario, 1:1 con auth.users.';
comment on column public.perfiles.monedas is 'Saldo cacheado; la fuente de verdad es transacciones_monedas.';

-- ---------------------------------------------------------------------
-- LIGA  (permite varias temporadas/competiciones)
-- ---------------------------------------------------------------------
create table public.ligas (
  id            uuid primary key default gen_random_uuid(),
  nombre        text not null,
  temporada     text not null,                 -- ej. '2026/27'
  activa        boolean not null default true,
  created_at    timestamptz not null default now(),
  unique (nombre, temporada)
);

-- ---------------------------------------------------------------------
-- INSCRIPCIONES  (qué usuarios participan en qué liga)
-- Necesaria para la clasificación: un usuario aparece aunque tenga 0 puntos.
-- ---------------------------------------------------------------------
create table public.liga_participantes (
  liga_id     uuid not null references public.ligas (id) on delete cascade,
  user_id     uuid not null references public.perfiles (id) on delete cascade,
  joined_at   timestamptz not null default now(),
  primary key (liga_id, user_id)
);

-- ---------------------------------------------------------------------
-- EQUIPOS
-- ---------------------------------------------------------------------
create table public.equipos (
  id            uuid primary key default gen_random_uuid(),
  liga_id       uuid not null references public.ligas (id) on delete cascade,
  nombre        text not null,
  escudo_url    text,
  unique (liga_id, nombre)
);

-- ---------------------------------------------------------------------
-- JORNADAS  (matchdays)
-- ---------------------------------------------------------------------
create table public.jornadas (
  id            uuid primary key default gen_random_uuid(),
  liga_id       uuid not null references public.ligas (id) on delete cascade,
  numero        int not null,
  nombre        text,
  estado        estado_jornada not null default 'borrador',
  -- Momento a partir del cual deja de poder comprarse/equiparse para esta jornada
  -- (normalmente = fecha_inicio del primer partido). Informativo; el time-lock real
  -- es por partido.
  fecha_cierre  timestamptz,
  created_at    timestamptz not null default now(),
  unique (liga_id, numero)
);

-- ---------------------------------------------------------------------
-- PARTIDOS
-- fecha_inicio es el campo CRÍTICO para la Regla 1 (time-locking).
-- ---------------------------------------------------------------------
create table public.partidos (
  id                  uuid primary key default gen_random_uuid(),
  jornada_id          uuid not null references public.jornadas (id) on delete cascade,
  equipo_local_id     uuid not null references public.equipos (id),
  equipo_visitante_id uuid not null references public.equipos (id),
  fecha_inicio        timestamptz not null,
  estado              estado_partido not null default 'programado',
  -- Resultado real (null hasta que se introduce).
  goles_local         smallint check (goles_local >= 0),
  goles_visitante     smallint check (goles_visitante >= 0),
  resultado_at        timestamptz,             -- cuándo se registró el resultado oficial
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  check (equipo_local_id <> equipo_visitante_id)
);

create index idx_partidos_jornada     on public.partidos (jornada_id);
create index idx_partidos_fecha_inicio on public.partidos (fecha_inicio);

comment on column public.partidos.fecha_inicio is
  'UTC. Fuente de verdad del time-lock: no se admiten cromos si now() >= fecha_inicio - 5 min.';

-- ---------------------------------------------------------------------
-- PRONÓSTICOS  (1 por usuario y partido)
-- ---------------------------------------------------------------------
create table public.pronosticos (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.perfiles (id) on delete cascade,
  partido_id      uuid not null references public.partidos (id) on delete cascade,
  goles_local     smallint not null check (goles_local >= 0),
  goles_visitante smallint not null check (goles_visitante >= 0),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (user_id, partido_id)
);

create index idx_pronosticos_partido on public.pronosticos (partido_id);

-- ---------------------------------------------------------------------
-- PUNTUACIONES  (resultado del escrutinio, por usuario y partido)
-- Se separa del pronóstico para conservar el desglose y permitir recálculos.
-- ---------------------------------------------------------------------
create table public.puntuaciones (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.perfiles (id) on delete cascade,
  partido_id        uuid not null references public.partidos (id) on delete cascade,
  jornada_id        uuid not null references public.jornadas (id) on delete cascade,
  puntos_base       int not null default 0,    -- 5 exacto / 2 signo / 0 fallo
  acierto_exacto    boolean not null default false,
  acierto_signo     boolean not null default false,
  -- puntos tras aplicar cromos de bonificación y ataques sobre este partido.
  puntos_finales    int not null default 0,
  detalle           jsonb not null default '{}'::jsonb,  -- trazabilidad de cromos aplicados
  created_at        timestamptz not null default now(),
  unique (user_id, partido_id)
);

create index idx_puntuaciones_jornada on public.puntuaciones (jornada_id);
create index idx_puntuaciones_user    on public.puntuaciones (user_id);

-- ---------------------------------------------------------------------
-- TRIGGER: mantener updated_at
-- ---------------------------------------------------------------------
create or replace function public.tg_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_perfiles_updated   before update on public.perfiles
  for each row execute function public.tg_set_updated_at();
create trigger trg_partidos_updated   before update on public.partidos
  for each row execute function public.tg_set_updated_at();
create trigger trg_pronosticos_updated before update on public.pronosticos
  for each row execute function public.tg_set_updated_at();

-- ---------------------------------------------------------------------
-- TRIGGER: crear perfil automáticamente al registrarse un usuario
-- ---------------------------------------------------------------------
create or replace function public.tg_crear_perfil()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.perfiles (id, username, nombre, monedas)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'username', 'user_' || left(new.id::text, 8)),
    coalesce(new.raw_user_meta_data ->> 'nombre', 'Jugador'),
    100   -- monedas de bienvenida
  );
  return new;
end;
$$;

create trigger trg_auth_user_creado
  after insert on auth.users
  for each row execute function public.tg_crear_perfil();
