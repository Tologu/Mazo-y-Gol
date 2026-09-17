-- 0042: premios de acierto 50 exacto / 20 signo; valor de enum para login diario

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
    when p_exacto then 50::bigint
    when p_signo  then 20::bigint
    else 0::bigint
  end;
$$;

comment on function public.fn_premio_por_acierto(boolean, boolean) is
  'Monedas que reparte un partido: 50 por marcador exacto, 20 por signo.';

alter type public.tipo_transaccion add value if not exists 'login_diario';
