-- =====================================================================
-- 0002_cromos_economia.sql
-- Catálogo de cromos, inventario de usuarios, ledger de monedas y
-- registro de cromos aplicados (bonificación equipada / ataque lanzado).
-- =====================================================================

-- ---------------------------------------------------------------------
-- ENUMS
-- ---------------------------------------------------------------------
create type tipo_cromo as enum (
  'bonificacion',   -- 🟢 modifica los puntos propios
  'ataque'          -- 🔴 modifica los puntos de un rival
);

create type rareza_cromo as enum ('comun', 'rara', 'epica', 'legendaria');

-- Estado de un cromo ya jugado en una jornada.
create type estado_cromo_aplicado as enum (
  'activo',     -- equipado/lanzado, pendiente de escrutinio
  'anulado',    -- cancelado por otro cromo de ataque (ej. "cancelar bonificación")
  'resuelto',   -- aplicado durante el escrutinio
  'reembolsado' -- devuelto (ej. partido suspendido)
);

-- Tipos de movimiento del ledger de monedas.
create type tipo_transaccion as enum (
  'bienvenida',
  'compra_cromo',
  'premio_jornada',
  'premio_clasificacion',
  'recompensa_sabotaje',
  'ajuste_admin'
);

-- ---------------------------------------------------------------------
-- CATÁLOGO DE CROMOS
-- El efecto se modela como JSONB para no tener que migrar la tabla cada vez
-- que se inventa una carta nueva. El motor de escrutinio interpreta 'efecto'.
-- ---------------------------------------------------------------------
create table public.cromos (
  id              uuid primary key default gen_random_uuid(),
  codigo          text unique not null,         -- ej. 'MULT_X2', 'AUTOBUS', 'CANCELAR_BONUS'
  nombre          text not null,
  descripcion     text not null,
  tipo            tipo_cromo not null,
  rareza          rareza_cromo not null default 'comun',
  -- Configuración del efecto, interpretada por el motor de escrutinio.
  -- ej. {"kind":"multiplicador","factor":2}
  --     {"kind":"seguro_empate","puntos":3}
  --     {"kind":"cancelar_bonificacion"}
  --     {"kind":"restar_si_falla","puntos":5}
  efecto          jsonb not null,
  -- ¿requiere que el usuario seleccione un partido al usarlo? (casi siempre sí)
  requiere_partido boolean not null default true,
  precio_monedas  bigint not null check (precio_monedas >= 0),
  comprable       boolean not null default true,  -- visible en la tienda
  icono_url       text,
  created_at      timestamptz not null default now()
);

comment on column public.cromos.efecto is
  'Config declarativa del efecto. La interpreta el motor de escrutinio (0004+).';

-- ---------------------------------------------------------------------
-- INVENTARIO  (stock de cromos por usuario)  -- Regla 3
-- ---------------------------------------------------------------------
create table public.inventarios (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.perfiles (id) on delete cascade,
  cromo_id    uuid not null references public.cromos (id) on delete restrict,
  cantidad    int not null default 0 check (cantidad >= 0),
  updated_at  timestamptz not null default now(),
  unique (user_id, cromo_id)
);

create index idx_inventarios_user on public.inventarios (user_id);

-- ---------------------------------------------------------------------
-- LEDGER DE MONEDAS  (fuente de verdad del saldo)
-- Cada fila es un movimiento; perfiles.monedas es un cache derivado.
-- ---------------------------------------------------------------------
create table public.transacciones_monedas (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.perfiles (id) on delete cascade,
  tipo            tipo_transaccion not null,
  -- delta: positivo = ingreso, negativo = gasto.
  cantidad        bigint not null,
  saldo_resultante bigint not null check (saldo_resultante >= 0),
  referencia      jsonb not null default '{}'::jsonb,  -- {cromo_id, jornada_id, ...}
  created_at      timestamptz not null default now()
);

create index idx_transacciones_user on public.transacciones_monedas (user_id, created_at desc);

-- ---------------------------------------------------------------------
-- CROMOS APLICADOS  (bonificación equipada / ataque lanzado)
-- Es el registro central de la "partida". Aquí viven las 3 reglas.
-- ---------------------------------------------------------------------
create table public.cromos_aplicados (
  id                uuid primary key default gen_random_uuid(),
  cromo_id          uuid not null references public.cromos (id) on delete restrict,
  -- snapshot del tipo/efecto en el momento del uso (por si el catálogo cambia)
  tipo              tipo_cromo not null,
  efecto            jsonb not null,
  -- quién lo usa
  emisor_user_id    uuid not null references public.perfiles (id) on delete cascade,
  -- objetivo: NULL para bonificación (sobre uno mismo); OBLIGATORIO para ataque.
  objetivo_user_id  uuid references public.perfiles (id) on delete cascade,
  partido_id        uuid not null references public.partidos (id) on delete cascade,
  jornada_id        uuid not null references public.jornadas (id) on delete cascade,
  estado            estado_cromo_aplicado not null default 'activo',
  -- para auditar la Regla +3 en el momento del lanzamiento:
  rango_emisor      int,    -- posición del atacante al lanzar
  rango_objetivo    int,    -- posición de la víctima al lanzar
  created_at        timestamptz not null default now(),

  -- INTEGRIDAD: un ataque SIEMPRE tiene objetivo; una bonificación NUNCA.
  constraint chk_objetivo_segun_tipo check (
    (tipo = 'ataque'       and objetivo_user_id is not null and objetivo_user_id <> emisor_user_id)
    or
    (tipo = 'bonificacion' and objetivo_user_id is null)
  )
);

create index idx_aplicados_partido  on public.cromos_aplicados (partido_id);
create index idx_aplicados_jornada  on public.cromos_aplicados (jornada_id);
create index idx_aplicados_emisor   on public.cromos_aplicados (emisor_user_id);
create index idx_aplicados_objetivo on public.cromos_aplicados (objetivo_user_id);

-- Un usuario no puede equipar el MISMO cromo de bonificación dos veces al mismo partido.
create unique index uq_bonif_unica_por_partido
  on public.cromos_aplicados (emisor_user_id, partido_id, cromo_id)
  where tipo = 'bonificacion' and estado = 'activo';

comment on table public.cromos_aplicados is
  'Registro de cromos jugados. rango_emisor/rango_objetivo dejan auditada la Regla +3.';
