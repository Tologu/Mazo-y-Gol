-- =====================================================================
-- 0034_fix_usar_cromo_v_chk.sql
-- En bonificaciones v_chk nunca se asigna. El CASE WHEN del INSERT
-- igual lee v_chk.rango_* y Postgres lanza:
--   record "v_chk" is not assigned yet
-- Se copian los rangos a enteros nulos y el INSERT ya no toca v_chk.
-- Parte de la versión de 0029.
-- =====================================================================

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
  v_chk            record;
  v_rango_emisor   int;
  v_rango_objetivo int;
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

    if not exists (
      select 1
      from public.liga_participantes lp
      where lp.liga_id = v_liga_id
        and lp.user_id = p_objetivo_user_id
    ) then
      raise exception 'El objetivo no participa en este servidor'
        using errcode = 'PT403', detail = 'objetivo_no_inscrito';
    end if;

    select * into v_chk
      from public.fn_ataque_permitido(v_liga_id, v_emisor, p_objetivo_user_id);

    if not v_chk.permitido then
      raise exception 'Ataque no permitido: %', v_chk.motivo
        using errcode = 'PT403', detail = v_chk.motivo;
    end if;

    v_rango_emisor   := v_chk.rango_atacante;
    v_rango_objetivo := v_chk.rango_objetivo;
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
end;
$$;

comment on function public.usar_cromo(uuid, uuid, uuid) is
  'Aplica un cromo del inventario de esa liga. Suspendidos siguen abiertos; finalizados o con marcador, no.';

grant execute on function public.usar_cromo(uuid, uuid, uuid) to authenticated;
