-- =====================================================================
-- 0024_apertura_secuencial_jornadas.sql
-- Solo una jornada abierta a pronósticos a la vez:
--   · Jornada 1: abierta hasta su cierre (fecha_inicio - 5 min).
--   · Jornada N: se abre cuando cierra la N-1 (mismo instante) y
--     permanece abierta hasta su propio cierre.
-- =====================================================================

-- Fecha de apertura = fecha_inicio (cierre) de la jornada anterior.
-- Jornada 1 → NULL (abierta desde el inicio de temporada).
create or replace function public.fn_fecha_apertura_jornada(p_jornada_id uuid)
returns timestamptz
language sql
stable
as $$
  select min(p_prev.fecha_inicio)
  from public.jornadas j
  join public.jornadas j_prev
    on j_prev.liga_id = j.liga_id
   and j_prev.numero = j.numero - 1
  join public.partidos p_prev
    on p_prev.jornada_id = j_prev.id
  where j.id = p_jornada_id;
$$;

comment on function public.fn_fecha_apertura_jornada(uuid) is
  'Cierre de la jornada anterior (fecha_inicio). NULL = jornada 1, sin espera.';

-- True si la jornada anterior ya cerró (o es la 1).
create or replace function public.fn_jornada_ya_abierta(p_jornada_id uuid)
returns boolean
language sql
stable
as $$
  select coalesce(
    now() >= (
      public.fn_fecha_apertura_jornada(p_jornada_id)
      - public.fn_margen_timelock()
    ),
    true
  );
$$;

comment on function public.fn_jornada_ya_abierta(uuid) is
  'True si ya se puede pronosticar esta jornada (la anterior ha cerrado).';

grant execute on function public.fn_fecha_apertura_jornada(uuid)
  to anon, authenticated;
grant execute on function public.fn_jornada_ya_abierta(uuid)
  to anon, authenticated;

-- ---------------------------------------------------------------------
-- Vista calendario: fecha_apertura + abierta
-- ---------------------------------------------------------------------
create or replace view public.v_partidos_calendario as
select
  p.id                                          as partido_id,
  j.id                                          as jornada_id,
  j.numero                                      as jornada_numero,
  j.nombre                                      as jornada_nombre,
  j.estado                                      as jornada_estado,
  l.id                                          as liga_id,
  l.nombre                                      as liga_nombre,
  el.nombre                                     as local,
  ev.nombre                                     as visitante,
  p.fecha_inicio,
  p.estado                                      as partido_estado,
  p.goles_local,
  p.goles_visitante,
  p.resultado_at,
  (p.goles_local is not null and p.goles_visitante is not null) as tiene_resultado,
  (now() >= (p.fecha_inicio - public.fn_margen_timelock()))     as bloqueado,
  l.slug                                        as liga_slug,
  prev.fecha_apertura,
  (
    (
      prev.fecha_apertura is null
      or now() >= (prev.fecha_apertura - public.fn_margen_timelock())
    )
    and now() < (p.fecha_inicio - public.fn_margen_timelock())
  ) as abierta
from public.partidos p
join public.jornadas j  on j.id  = p.jornada_id
join public.ligas l     on l.id  = j.liga_id
join public.equipos el  on el.id = p.equipo_local_id
join public.equipos ev  on ev.id = p.equipo_visitante_id
left join lateral (
  select min(p_prev.fecha_inicio) as fecha_apertura
  from public.jornadas j_prev
  join public.partidos p_prev on p_prev.jornada_id = j_prev.id
  where j_prev.liga_id = j.liga_id
    and j_prev.numero = j.numero - 1
) prev on true
order by j.numero, p.fecha_inicio;

grant select on public.v_partidos_calendario to anon, authenticated;

-- ---------------------------------------------------------------------
-- RLS: no insertar/editar pronósticos de jornadas aún no abiertas
-- ---------------------------------------------------------------------
drop policy if exists pronosticos_insert_propio on public.pronosticos;
drop policy if exists pronosticos_update_propio on public.pronosticos;

create policy pronosticos_insert_propio on public.pronosticos
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.partidos p
      where p.id = partido_id
        and now() < (p.fecha_inicio - public.fn_margen_timelock())
        and public.fn_jornada_ya_abierta(p.jornada_id)
    )
  );

create policy pronosticos_update_propio on public.pronosticos
  for update using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.partidos p
      where p.id = partido_id
        and now() < (p.fecha_inicio - public.fn_margen_timelock())
        and public.fn_jornada_ya_abierta(p.jornada_id)
    )
  );

-- ---------------------------------------------------------------------
-- guardar_pronostico: gate jornada anterior
-- ---------------------------------------------------------------------
create or replace function public.guardar_pronostico(
  p_partido_id      uuid,
  p_goles_local     smallint,
  p_goles_visitante smallint
)
returns public.pronosticos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_partido public.partidos%rowtype;
  v_liga_id uuid;
  v_pron    public.pronosticos%rowtype;
begin
  if v_user_id is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  if p_goles_local < 0 or p_goles_visitante < 0 then
    raise exception 'Marcador inválido' using errcode = 'PT400';
  end if;

  select p.* into v_partido
  from public.partidos p
  where p.id = p_partido_id;

  if not found then
    raise exception 'Partido no encontrado' using errcode = 'PT404';
  end if;

  if v_partido.goles_local is not null
     or v_partido.goles_visitante is not null
     or v_partido.estado = 'finalizado' then
    raise exception 'El partido ya tiene resultado y no admite pronósticos'
      using errcode = 'PT403', detail = 'partido_cerrado';
  end if;

  if not public.fn_jornada_ya_abierta(v_partido.jornada_id) then
    raise exception 'La jornada anterior aún no ha cerrado'
      using errcode = 'PT403', detail = 'jornada_no_abierta';
  end if;

  -- Suspendido: se puede pronosticar aunque haya pasado la hora.
  if v_partido.estado <> 'suspendido'
     and now() >= (v_partido.fecha_inicio - public.fn_margen_timelock()) then
    raise exception 'El partido ya está bloqueado para pronósticos'
      using errcode = 'PT403', detail = 'time_lock';
  end if;

  select j.liga_id into v_liga_id
  from public.jornadas j
  where j.id = v_partido.jornada_id;

  if not exists (
    select 1
    from public.liga_participantes lp
    where lp.liga_id = v_liga_id
      and lp.user_id = v_user_id
  ) then
    raise exception 'No estás inscrito en esta liga'
      using errcode = 'PT403', detail = 'no_inscrito';
  end if;

  insert into public.pronosticos (
    user_id, partido_id, goles_local, goles_visitante
  )
  values (
    v_user_id, p_partido_id, p_goles_local, p_goles_visitante
  )
  on conflict (user_id, partido_id) do update set
    goles_local     = excluded.goles_local,
    goles_visitante = excluded.goles_visitante,
    updated_at      = now()
  returning * into v_pron;

  return v_pron;
end;
$$;

comment on function public.guardar_pronostico is
  'Guarda pronóstico. Requiere jornada abierta (la anterior cerrada). Suspendidos admiten pronóstico tras el cierre.';

grant execute on function public.guardar_pronostico(uuid, smallint, smallint)
  to authenticated;

-- ---------------------------------------------------------------------
-- usar_cromo: misma ventana de apertura
-- ---------------------------------------------------------------------
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
  v_emisor        uuid := auth.uid();
  v_cromo         public.cromos%rowtype;
  v_partido       public.partidos%rowtype;
  v_jornada       public.jornadas%rowtype;
  v_liga_id       uuid;
  v_modo          text;
  v_stock         int;
  v_aplicado      public.cromos_aplicados%rowtype;
  v_chk           record;
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

  select l.modo_juego into v_modo
    from public.ligas l
   where l.id = v_liga_id;

  if coalesce(v_modo, 'clasica') = 'clasica' then
    raise exception 'Esta porra es Clásica: los cromos están deshabilitados'
      using errcode = 'PT403', detail = 'cromos_deshabilitados';
  end if;

  if not public.fn_jornada_ya_abierta(v_partido.jornada_id) then
    raise exception 'La jornada anterior aún no ha cerrado'
      using errcode = 'PT403', detail = 'jornada_no_abierta';
  end if;

  if now() >= (v_partido.fecha_inicio - public.fn_margen_timelock()) then
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

    select * into v_chk
      from public.fn_ataque_permitido(v_liga_id, v_emisor, p_objetivo_user_id);

    if not v_chk.permitido then
      raise exception 'Ataque no permitido: %', v_chk.motivo
        using errcode = 'PT403', detail = v_chk.motivo;
    end if;
  end if;

  select cantidad into v_stock
    from public.inventarios
   where user_id = v_emisor and cromo_id = p_cromo_id
   for update;

  if v_stock is null or v_stock < 1 then
    raise exception 'No tienes ese cromo en el inventario'
      using errcode = 'PT403', detail = 'sin_stock';
  end if;

  update public.inventarios
     set cantidad = cantidad - 1,
         updated_at = now()
   where user_id = v_emisor and cromo_id = p_cromo_id;

  insert into public.cromos_aplicados (
    cromo_id, tipo, efecto,
    emisor_user_id, objetivo_user_id,
    partido_id, jornada_id, estado,
    rango_emisor, rango_objetivo
  ) values (
    v_cromo.id, v_cromo.tipo, v_cromo.efecto,
    v_emisor, p_objetivo_user_id,
    v_partido.id, v_jornada.id, 'activo',
    case when v_cromo.tipo = 'ataque' then v_chk.rango_atacante end,
    case when v_cromo.tipo = 'ataque' then v_chk.rango_objetivo end
  )
  returning * into v_aplicado;

  return v_aplicado;
end;
$$;

comment on function public.usar_cromo(uuid, uuid, uuid) is
  'Aplica un cromo; bloqueado si clasica, jornada no abierta o time-lock.';
