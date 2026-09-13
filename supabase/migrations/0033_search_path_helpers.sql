-- =====================================================================
-- 0033_search_path_helpers.sql
-- Las dos funciones constantes de 0028 y 0031 se crearon sin search_path
-- fijo y el linter de Supabase las marca. No tocan tablas, así que es
-- higiene, pero conviene dejarlas igual que el resto.
-- =====================================================================

create or replace function public.fn_monedas_bienvenida()
returns bigint
language sql
immutable
set search_path = public
as $$
  select 200::bigint;
$$;

create or replace function public.fn_premio_por_acierto(
  p_exacto boolean,
  p_signo  boolean
)
returns bigint
language sql
immutable
set search_path = public
as $$
  select case
    when p_exacto then 10::bigint
    when p_signo  then 4::bigint
    else 0::bigint
  end;
$$;

comment on function public.fn_premio_por_acierto(boolean, boolean) is
  'Monedas que reparte un partido: 10 por marcador exacto, 4 por signo.';
