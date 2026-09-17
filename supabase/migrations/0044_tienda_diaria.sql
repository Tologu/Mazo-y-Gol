-- 0044: tienda diaria por jugador (3 cartas, rota a las 00:00 Europe/Madrid)

create or replace function public.fn_tamano_tienda_diaria()
returns int
language sql
immutable
set search_path = public
as $$
  select 3;
$$;

comment on function public.fn_tamano_tienda_diaria() is
  'Cuántas cartas distintas ve cada jugador en la tienda cada día.';

revoke execute on function public.fn_tamano_tienda_diaria() from public, anon, authenticated;

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
  select ranked.id
    from (
      select c.id,
             row_number() over (
               order by md5(
                 c.id::text
                 || chr(30)
                 || p_user_id::text
                 || chr(30)
                 || p_liga_id::text
                 || chr(30)
                 || coalesce(
                      p_fecha,
                      (timezone('Europe/Madrid', now()))::date
                    )::text
               )
             ) as n
        from public.cromos c
       where c.comprable
         and p_user_id is not null
         and p_liga_id is not null
    ) ranked
   where ranked.n <= public.fn_tamano_tienda_diaria();
$$;

comment on function public.fn_ids_tienda_diaria(uuid, uuid, date) is
  'Oferta determinista de tienda: misma persona y día, mismas cartas; cambia a medianoche Madrid.';

revoke execute on function public.fn_ids_tienda_diaria(uuid, uuid, date) from public, anon, authenticated;

create or replace function public.fn_cromos_tienda_hoy(p_liga_id uuid)
returns table (
  cromo_id     uuid,
  codigo       text,
  nombre       text,
  descripcion  text,
  tipo         text,
  rareza       text,
  efecto       jsonb,
  precio       bigint,
  cantidad     int
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id,
    c.codigo,
    c.nombre,
    c.descripcion,
    c.tipo::text,
    c.rareza::text,
    c.efecto,
    c.precio_monedas,
    coalesce(i.cantidad, 0)
  from public.fn_ids_tienda_diaria(p_liga_id, auth.uid()) t
  join public.cromos c on c.id = t.cromo_id
  left join public.inventarios i
         on i.cromo_id = c.id
        and i.liga_id  = p_liga_id
        and i.user_id  = auth.uid()
  where exists (
    select 1 from public.liga_participantes lp
     where lp.liga_id = p_liga_id
       and lp.user_id = auth.uid()
  )
  order by c.tipo, c.precio_monedas, c.nombre;
$$;

comment on function public.fn_cromos_tienda_hoy(uuid) is
  'Las 3 cartas de la tienda de hoy del usuario autenticado en esa liga.';

revoke execute on function public.fn_cromos_tienda_hoy(uuid) from public, anon;
grant execute on function public.fn_cromos_tienda_hoy(uuid) to authenticated;

create or replace function public.comprar_cromo(
  p_cromo_id uuid,
  p_liga_id  uuid
)
returns public.inventarios
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_cromo  public.cromos%rowtype;
  v_modo   text;
  v_saldo  bigint;
  v_inv    public.inventarios%rowtype;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  select l.modo_juego into v_modo
    from public.ligas l
   where l.id = p_liga_id;

  if not found then
    raise exception 'El servidor no existe' using errcode = 'PT404';
  end if;

  if coalesce(v_modo, 'clasica') = 'clasica' then
    raise exception 'Esta porra es Clásica: los cromos están deshabilitados'
      using errcode = 'PT403', detail = 'cromos_deshabilitados';
  end if;

  select * into v_cromo from public.cromos where id = p_cromo_id;
  if not found then
    raise exception 'El cromo no existe' using errcode = 'PT404';
  end if;

  if not v_cromo.comprable then
    raise exception 'Ese cromo no está a la venta'
      using errcode = 'PT403', detail = 'no_comprable';
  end if;

  if not exists (
    select 1
      from public.fn_ids_tienda_diaria(p_liga_id, v_uid) t
     where t.cromo_id = p_cromo_id
  ) then
    raise exception 'Esa carta no está en tu tienda de hoy'
      using errcode = 'PT403', detail = 'no_en_tienda_hoy';
  end if;

  select lp.monedas into v_saldo
    from public.liga_participantes lp
   where lp.liga_id = p_liga_id
     and lp.user_id = v_uid
   for update;

  if v_saldo is null then
    raise exception 'No estás inscrito en esta liga'
      using errcode = 'PT403', detail = 'no_inscrito';
  end if;

  if v_saldo < v_cromo.precio_monedas then
    raise exception 'No tienes monedas suficientes'
      using errcode = 'PT403', detail = 'saldo_insuficiente';
  end if;

  update public.liga_participantes
     set monedas = monedas - v_cromo.precio_monedas
   where liga_id = p_liga_id
     and user_id = v_uid
  returning monedas into v_saldo;

  insert into public.inventarios as inv (user_id, liga_id, cromo_id, cantidad)
  values (v_uid, p_liga_id, p_cromo_id, 1)
  on conflict (user_id, liga_id, cromo_id) do update
    set cantidad   = inv.cantidad + 1,
        updated_at = now()
  returning * into v_inv;

  insert into public.transacciones_monedas (
    user_id, liga_id, tipo, cantidad, saldo_resultante, referencia
  ) values (
    v_uid, p_liga_id, 'compra_cromo',
    -v_cromo.precio_monedas, v_saldo,
    jsonb_build_object('cromo_id', p_cromo_id, 'codigo', v_cromo.codigo)
  );

  return v_inv;
end;
$$;

comment on function public.comprar_cromo(uuid, uuid) is
  'Compra un cromo de la tienda de hoy del jugador en esa liga.';

revoke execute on function public.comprar_cromo(uuid, uuid) from public, anon;
grant execute on function public.comprar_cromo(uuid, uuid) to authenticated;
