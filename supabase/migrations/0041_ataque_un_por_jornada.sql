-- 0041: ataques a cualquiera; un jugador solo recibe 1 ataque por jornada

delete from public.cromos_aplicados ca
 where ca.tipo = 'ataque'
   and ca.estado in ('activo', 'resuelto', 'anulado')
   and ca.objetivo_user_id is not null
   and ca.id not in (
     select kept.id
       from (
         select distinct on (jornada_id, objetivo_user_id) id
           from public.cromos_aplicados
          where tipo = 'ataque'
            and estado in ('activo', 'resuelto', 'anulado')
            and objetivo_user_id is not null
          order by jornada_id, objetivo_user_id, created_at
       ) kept
   );

create unique index if not exists uq_un_ataque_recibido_jornada
  on public.cromos_aplicados (jornada_id, objetivo_user_id)
  where tipo = 'ataque'
    and objetivo_user_id is not null
    and estado in ('activo', 'resuelto', 'anulado');

create or replace function public.fn_ya_atacados_jornada(
  p_liga_id uuid,
  p_jornada int
)
returns table (user_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select distinct ca.objetivo_user_id
    from public.cromos_aplicados ca
    join public.jornadas j on j.id = ca.jornada_id
   where j.liga_id = p_liga_id
     and j.numero = p_jornada
     and ca.tipo = 'ataque'
     and ca.estado in ('activo', 'resuelto', 'anulado')
     and ca.objetivo_user_id is not null
     and exists (
       select 1 from public.liga_participantes lp
        where lp.liga_id = p_liga_id
          and lp.user_id = auth.uid()
     );
$$;

comment on function public.fn_ya_atacados_jornada(uuid, int) is
  'Jugadores que ya han recibido un ataque (activo, resuelto o anulado) en esa jornada.';

revoke execute on function public.fn_ya_atacados_jornada(uuid, int) from public, anon;
grant execute on function public.fn_ya_atacados_jornada(uuid, int) to authenticated;

create or replace function public.usar_cromo(
  p_cromo_id          uuid,
  p_partido_id        uuid,
  p_objetivo_user_id  uuid default null
)
returns public.cromos_aplicados
language plpgsql
security definer
set search_path = public
as $$
declare
  v_emisor         uuid := auth.uid();
  v_cromo          public.cromos%rowtype;
  v_partido        public.partidos%rowtype;
  v_jornada        public.jornadas%rowtype;
  v_liga_id        uuid;
  v_modo           text;
  v_stock          int;
  v_aplicado       public.cromos_aplicados%rowtype;
  v_rango_emisor   int;
  v_rango_objetivo int;
  v_constraint     text;
begin
  if v_emisor is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  select * into v_cromo from public.cromos where id = p_cromo_id;
  if not found then
    raise exception 'El cromo no existe' using errcode = 'PT404';
  end if;

  select * into v_partido from public.partidos where id = p_partido_id;
  if not found then
    raise exception 'El partido no existe' using errcode = 'PT404';
  end if;

  select * into v_jornada from public.jornadas where id = v_partido.jornada_id;
  v_liga_id := v_jornada.liga_id;

  if not exists (
    select 1
    from public.liga_participantes lp
    where lp.liga_id = v_liga_id
      and lp.user_id = v_emisor
  ) then
    raise exception 'No estás inscrito en esta liga'
      using errcode = 'PT403', detail = 'no_inscrito';
  end if;

  select l.modo_juego into v_modo
    from public.ligas l
   where l.id = v_liga_id;

  if coalesce(v_modo, 'clasica') = 'clasica' then
    raise exception 'Esta porra es Clásica: los cromos están deshabilitados'
      using errcode = 'PT403', detail = 'cromos_deshabilitados';
  end if;

  if v_partido.goles_local is not null
     or v_partido.goles_visitante is not null
     or v_partido.estado = 'finalizado' then
    raise exception 'El partido ya tiene resultado'
      using errcode = 'PT403', detail = 'partido_cerrado';
  end if;

  if not public.fn_jornada_ya_abierta(v_partido.jornada_id) then
    raise exception 'La jornada anterior aún no ha cerrado'
      using errcode = 'PT403', detail = 'jornada_no_abierta';
  end if;

  if v_partido.estado <> 'suspendido'
     and now() >= (v_partido.fecha_inicio - public.fn_margen_timelock()) then
    raise exception 'El partido ya está bloqueado (time-lock)'
      using errcode = 'PT403', detail = 'time_lock';
  end if;

  if v_cromo.tipo = 'bonificacion' then
    if p_objetivo_user_id is not null then
      raise exception 'Una bonificación no puede tener objetivo'
        using errcode = 'PT400', detail = 'bonificacion_con_objetivo';
    end if;

  elsif v_cromo.tipo = 'ataque' then
    if p_objetivo_user_id is null then
      raise exception 'Un ataque requiere un objetivo'
        using errcode = 'PT400', detail = 'ataque_sin_objetivo';
    end if;

    if p_objetivo_user_id = v_emisor then
      raise exception 'No puedes atacarte a ti mismo'
        using errcode = 'PT403', detail = 'no_puedes_atacarte';
    end if;

    if not exists (
      select 1
      from public.liga_participantes lp
      where lp.liga_id = v_liga_id
        and lp.user_id = p_objetivo_user_id
    ) then
      raise exception 'El objetivo no participa en este servidor'
        using errcode = 'PT403', detail = 'objetivo_no_inscrito';
    end if;

    if exists (
      select 1
        from public.cromos_aplicados ca
       where ca.jornada_id = v_jornada.id
         and ca.objetivo_user_id = p_objetivo_user_id
         and ca.tipo = 'ataque'
         and ca.estado in ('activo', 'resuelto', 'anulado')
    ) then
      raise exception 'Ese jugador ya ha recibido un ataque esta jornada'
        using errcode = 'PT403', detail = 'ya_recibio_ataque';
    end if;
  end if;

  select cantidad into v_stock
    from public.inventarios
   where user_id = v_emisor
     and liga_id = v_liga_id
     and cromo_id = p_cromo_id
   for update;

  if v_stock is null or v_stock < 1 then
    raise exception 'No tienes ese cromo en el inventario'
      using errcode = 'PT403', detail = 'sin_stock';
  end if;

  update public.inventarios
     set cantidad = cantidad - 1,
         updated_at = now()
   where user_id = v_emisor
     and liga_id = v_liga_id
     and cromo_id = p_cromo_id;

  insert into public.cromos_aplicados (
    cromo_id, tipo, efecto,
    emisor_user_id, objetivo_user_id,
    partido_id, jornada_id, estado,
    rango_emisor, rango_objetivo
  ) values (
    v_cromo.id, v_cromo.tipo, v_cromo.efecto,
    v_emisor, p_objetivo_user_id,
    v_partido.id, v_jornada.id, 'activo',
    v_rango_emisor,
    v_rango_objetivo
  )
  returning * into v_aplicado;

  return v_aplicado;
exception
  when unique_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint = 'uq_un_ataque_recibido_jornada' then
      raise exception 'Ese jugador ya ha recibido un ataque esta jornada'
        using errcode = 'PT403', detail = 'ya_recibio_ataque';
    end if;
    raise;
end;
$$;

comment on function public.usar_cromo(uuid, uuid, uuid) is
  'Aplica un cromo. Ataques: cualquier rival de la liga, un solo ataque recibido por jornada.';

revoke execute on function public.usar_cromo(uuid, uuid, uuid) from public, anon;
grant execute on function public.usar_cromo(uuid, uuid, uuid) to authenticated;
