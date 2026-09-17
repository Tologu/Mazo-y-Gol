-- 0033: search_path en fn_monedas_bienvenida y fn_premio_por_acierto

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
