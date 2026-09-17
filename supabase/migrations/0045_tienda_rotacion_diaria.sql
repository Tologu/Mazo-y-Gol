-- 0045: la ventana de tienda se desplaza cada día para no repetir el mismo lote

create or replace function public.fn_ids_tienda_diaria(
  p_liga_id uuid,
  p_user_id uuid,
  p_fecha date default null
)
returns table (cromo_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  with catalogo as (
    select c.id,
           row_number() over (
             order by md5(
               c.id::text
               || chr(30)
               || p_user_id::text
               || chr(30)
               || p_liga_id::text
             )
           ) - 1 as idx,
           count(*) over () as n
      from public.cromos c
     where c.comprable
       and p_user_id is not null
       and p_liga_id is not null
  ),
  params as (
    select coalesce(
             p_fecha,
             (timezone('Europe/Madrid', now()))::date
           ) as d
  )
  select c.id
    from catalogo c
    cross join params p
   where c.n > 0
     and mod(
           c.idx
           - mod(
               (p.d - date '2000-01-01') * public.fn_tamano_tienda_diaria(),
               c.n
             )
           + c.n,
           c.n
         ) < least(public.fn_tamano_tienda_diaria(), c.n);
$$;

comment on function public.fn_ids_tienda_diaria(uuid, uuid, date) is
  'Oferta por jugador: orden propio del catálogo y ventana que avanza cada medianoche Madrid.';
