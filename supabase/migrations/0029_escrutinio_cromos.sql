-- 0029: el escrutinio aplica cromos sobre puntos_finales
-- tijeras primero, luego bonus, luego ataques.
-- Autobús puede dejar puntos negativos (si no, no haría nada).


-- ---------------------------------------------------------------------
-- Cálculo de los cromos de UN jugador en UN partido.
-- Devuelve {"puntos": int, "cromos": [ {codigo, nombre, tipo, delta}, ... ]}
-- ---------------------------------------------------------------------
create or replace function public.fn_aplicar_cromos_partido(
  p_partido_id  uuid,
  p_user_id     uuid,
  p_puntos_base int
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_puntos int  := p_puntos_base;
  v_prev   int;
  v_valor  int;
  v_traza  jsonb := '[]'::jsonb;
  v_row    record;
  v_kind   text;
begin
  -- (B) Bonificaciones propias vivas. Las anuladas por Tijeras quedan fuera.
  for v_row in
    select ca.efecto, c.codigo, c.nombre
      from public.cromos_aplicados ca
      join public.cromos c on c.id = ca.cromo_id
     where ca.partido_id     = p_partido_id
       and ca.emisor_user_id = p_user_id
       and ca.tipo           = 'bonificacion'
       and ca.estado         = 'activo'
     order by ca.created_at
  loop
    v_prev := v_puntos;
    v_kind := v_row.efecto->>'kind';

    if v_kind = 'multiplicador' then
      v_valor  := coalesce((v_row.efecto->>'factor')::int, 1);
      v_puntos := v_puntos * v_valor;

    elsif v_kind = 'seguro' then
      v_valor := coalesce((v_row.efecto->>'puntos')::int, 0);
      if p_puntos_base = 0 then
        v_puntos := greatest(v_puntos, v_valor);
      end if;
    end if;

    if v_puntos <> v_prev then
      v_traza := v_traza || jsonb_build_object(
        'codigo', v_row.codigo,
        'nombre', v_row.nombre,
        'tipo',   'bonificacion',
        'delta',  v_puntos - v_prev
      );
    end if;
  end loop;

  -- (C) Ataques recibidos.
  for v_row in
    select ca.efecto, c.codigo, c.nombre
      from public.cromos_aplicados ca
      join public.cromos c on c.id = ca.cromo_id
     where ca.partido_id       = p_partido_id
       and ca.objetivo_user_id = p_user_id
       and ca.tipo             = 'ataque'
       and ca.estado           = 'activo'
     order by ca.created_at
  loop
    v_prev := v_puntos;
    v_kind := v_row.efecto->>'kind';

    if v_kind = 'restar_si_falla' and p_puntos_base = 0 then
      v_valor  := coalesce((v_row.efecto->>'puntos')::int, 0);
      v_puntos := v_puntos - v_valor;
    end if;

    -- Las Tijeras no cambian el marcador por sí solas (su efecto ya está
    -- reflejado en la bonificación anulada), pero se dejan en la traza
    -- para que la víctima sepa qué le pasó.
    if v_puntos <> v_prev or v_kind = 'cancelar_bonificacion' then
      v_traza := v_traza || jsonb_build_object(
        'codigo', v_row.codigo,
        'nombre', v_row.nombre,
        'tipo',   'ataque',
        'delta',  v_puntos - v_prev
      );
    end if;
  end loop;

  return jsonb_build_object('puntos', v_puntos, 'cromos', v_traza);
end;
$$;

comment on function public.fn_aplicar_cromos_partido(uuid, uuid, int) is
  'Puntos de un jugador en un partido tras aplicar sus bonificaciones y los ataques recibidos.';

-- ---------------------------------------------------------------------
-- Escrutinio interno (sin control de acceso), ahora con cromos.
-- ---------------------------------------------------------------------
create or replace function public.fn_escrutar_partido_interno(p_partido_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_partido    public.partidos%rowtype;
  v_insertados int := 0;
  v_row        record;
  v_calc       record;
  v_cromos     jsonb;
begin
  select * into v_partido from public.partidos where id = p_partido_id;
  if not found then
    raise exception 'Partido no encontrado' using errcode = 'PT404';
  end if;

  if v_partido.goles_local is null or v_partido.goles_visitante is null then
    raise exception 'El partido no tiene resultado oficial'
      using errcode = 'PT400', detail = 'resultado_incompleto';
  end if;

  if v_partido.estado = 'suspendido' then
    raise exception 'El partido está suspendido y no se puede escrutar'
      using errcode = 'PT400', detail = 'partido_suspendido';
  end if;

  -- Idempotencia: se recalcula desde cero en cada escrutinio.
  -- Los reembolsados quedan fuera: esas cartas ya volvieron al mazo.
  update public.cromos_aplicados
     set estado = 'activo'
   where partido_id = p_partido_id
     and estado in ('resuelto', 'anulado');

  -- (A) Las Tijeras anulan las bonificaciones de su objetivo.
  update public.cromos_aplicados b
     set estado = 'anulado'
   where b.partido_id = p_partido_id
     and b.tipo       = 'bonificacion'
     and b.estado     = 'activo'
     and exists (
       select 1
         from public.cromos_aplicados a
        where a.partido_id       = p_partido_id
          and a.tipo             = 'ataque'
          and a.estado           = 'activo'
          and a.efecto->>'kind'  = 'cancelar_bonificacion'
          and a.objetivo_user_id = b.emisor_user_id
     );

  for v_row in
    select pr.user_id, pr.goles_local, pr.goles_visitante
      from public.pronosticos pr
     where pr.partido_id = p_partido_id
  loop
    select * into v_calc
      from public.fn_puntos_base_partido(
        v_row.goles_local,
        v_row.goles_visitante,
        v_partido.goles_local,
        v_partido.goles_visitante
      );

    v_cromos := public.fn_aplicar_cromos_partido(
      p_partido_id, v_row.user_id, v_calc.puntos_base
    );

    insert into public.puntuaciones (
      user_id, partido_id, jornada_id,
      puntos_base, acierto_exacto, acierto_signo,
      puntos_finales, detalle
    ) values (
      v_row.user_id, p_partido_id, v_partido.jornada_id,
      v_calc.puntos_base, v_calc.acierto_exacto, v_calc.acierto_signo,
      (v_cromos->>'puntos')::int,
      jsonb_build_object(
        'fase', 'cromos',
        'pronostico', jsonb_build_object('local', v_row.goles_local, 'visitante', v_row.goles_visitante),
        'resultado',  jsonb_build_object('local', v_partido.goles_local, 'visitante', v_partido.goles_visitante),
        'signo_pronostico', public.fn_signo_resultado(v_row.goles_local, v_row.goles_visitante),
        'signo_real',       public.fn_signo_resultado(v_partido.goles_local, v_partido.goles_visitante),
        'cromos', v_cromos->'cromos'
      )
    )
    on conflict (user_id, partido_id) do update set
      puntos_base     = excluded.puntos_base,
      acierto_exacto  = excluded.acierto_exacto,
      acierto_signo   = excluded.acierto_signo,
      puntos_finales  = excluded.puntos_finales,
      detalle         = excluded.detalle;

    v_insertados := v_insertados + 1;
  end loop;

  -- Los que han llegado vivos al final quedan consumidos.
  update public.cromos_aplicados
     set estado = 'resuelto'
   where partido_id = p_partido_id
     and estado = 'activo';

  return v_insertados;
end;
$$;

comment on function public.fn_escrutar_partido_interno is
  'Escrutinio de un partido con cromos aplicados. Sin control de acceso: solo desde RPCs que ya validan permisos.';

-- ---------------------------------------------------------------------
-- REEMBOLSO
-- Un partido suspendido no puntúa, así que las cartas jugadas vuelven
-- al mazo del jugador en esa liga.
-- ---------------------------------------------------------------------
create or replace function public.fn_reembolsar_cromos_partido(p_partido_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
  v_n   int := 0;
begin
  for v_row in
    select ca.id, ca.cromo_id, ca.emisor_user_id, j.liga_id
      from public.cromos_aplicados ca
      join public.jornadas j on j.id = ca.jornada_id
     where ca.partido_id = p_partido_id
       and ca.estado <> 'reembolsado'
  loop
    insert into public.inventarios as inv (user_id, liga_id, cromo_id, cantidad)
    values (v_row.emisor_user_id, v_row.liga_id, v_row.cromo_id, 1)
    on conflict (user_id, liga_id, cromo_id) do update
      set cantidad   = inv.cantidad + 1,
          updated_at = now();

    update public.cromos_aplicados
       set estado = 'reembolsado'
     where id = v_row.id;

    v_n := v_n + 1;
  end loop;

  return v_n;
end;
$$;

comment on function public.fn_reembolsar_cromos_partido(uuid) is
  'Devuelve al inventario los cromos jugados en un partido y los marca reembolsados.';

-- ---------------------------------------------------------------------
-- suspender_partido_liga: además de borrar puntos, devolver los cromos.
-- Parte de la versión de 0018.
-- ---------------------------------------------------------------------
create or replace function public.suspender_partido_liga(
  p_liga_id    uuid,
  p_partido_id uuid
)
returns public.partidos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_partido public.partidos%rowtype;
begin
  if auth.uid() is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  if not public.fn_es_owner_liga(p_liga_id) then
    raise exception 'Solo el dueño del servidor puede suspender partidos'
      using errcode = 'PT403', detail = 'no_owner';
  end if;

  if not exists (
    select 1
    from public.partidos p
    join public.jornadas j on j.id = p.jornada_id
    where p.id = p_partido_id
      and j.liga_id = p_liga_id
  ) then
    raise exception 'El partido no pertenece a este servidor'
      using errcode = 'PT404', detail = 'partido_ajeno';
  end if;

  delete from public.puntuaciones where partido_id = p_partido_id;

  -- El partido no puntúa: las cartas vuelven al mazo y se pueden
  -- volver a jugar cuando el dueño registre el resultado real.
  perform public.fn_reembolsar_cromos_partido(p_partido_id);

  update public.partidos
     set estado          = 'suspendido',
         goles_local     = null,
         goles_visitante = null,
         resultado_at    = null,
         updated_at      = now()
   where id = p_partido_id
  returning * into v_partido;

  return v_partido;
end;
$$;

comment on function public.suspender_partido_liga is
  'Dueño: marca partido suspendido, borra puntos y reembolsa los cromos jugados.';

grant execute on function public.suspender_partido_liga(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------
-- usar_cromo: permitir cromos en partidos suspendidos sin resultado,
-- igual que ya se hizo con los pronósticos en 0019.
-- Parte de la versión de 0027 (inventario por liga).
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

  -- Con resultado oficial o finalizado ya no se puede jugar nada.
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

  -- Suspendido: sigue abierto aunque haya pasado la hora. Resto: time-lock.
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
    case when v_cromo.tipo = 'ataque' then v_chk.rango_atacante end,
    case when v_cromo.tipo = 'ataque' then v_chk.rango_objetivo end
  )
  returning * into v_aplicado;

  return v_aplicado;
end;
$$;

comment on function public.usar_cromo(uuid, uuid, uuid) is
  'Aplica un cromo del inventario de esa liga. Suspendidos siguen abiertos; finalizados o con marcador, no.';

grant execute on function public.usar_cromo(uuid, uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------
-- CANCELAR UN CROMO YA JUGADO
-- Mientras el partido siga abierto, el jugador puede retirar la carta y
-- recuperarla. Sin esto un clic equivocado se paga toda la jornada.
-- ---------------------------------------------------------------------
create or replace function public.cancelar_cromo(p_aplicado_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid      uuid := auth.uid();
  v_aplicado public.cromos_aplicados%rowtype;
  v_partido  public.partidos%rowtype;
  v_liga_id  uuid;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  select * into v_aplicado
    from public.cromos_aplicados
   where id = p_aplicado_id
   for update;

  if not found then
    raise exception 'Ese cromo no está en juego' using errcode = 'PT404';
  end if;

  if v_aplicado.emisor_user_id <> v_uid then
    raise exception 'Solo puedes retirar tus propios cromos'
      using errcode = 'PT403', detail = 'no_es_tuyo';
  end if;

  if v_aplicado.estado <> 'activo' then
    raise exception 'Ese cromo ya se ha resuelto'
      using errcode = 'PT403', detail = 'cromo_resuelto';
  end if;

  select * into v_partido
    from public.partidos
   where id = v_aplicado.partido_id;

  if v_partido.goles_local is not null
     or v_partido.goles_visitante is not null
     or v_partido.estado = 'finalizado' then
    raise exception 'El partido ya tiene resultado'
      using errcode = 'PT403', detail = 'partido_cerrado';
  end if;

  if v_partido.estado <> 'suspendido'
     and now() >= (v_partido.fecha_inicio - public.fn_margen_timelock()) then
    raise exception 'El partido ya está bloqueado (time-lock)'
      using errcode = 'PT403', detail = 'time_lock';
  end if;

  select j.liga_id into v_liga_id
    from public.jornadas j
   where j.id = v_aplicado.jornada_id;

  insert into public.inventarios (user_id, liga_id, cromo_id, cantidad)
  values (v_uid, v_liga_id, v_aplicado.cromo_id, 1)
  on conflict (user_id, liga_id, cromo_id) do update
    set cantidad   = public.inventarios.cantidad + 1,
        updated_at = now();

  update public.cromos_aplicados
     set estado = 'reembolsado'
   where id = p_aplicado_id;
end;
$$;

comment on function public.cancelar_cromo(uuid) is
  'Retira un cromo propio aún no resuelto y lo devuelve al mazo de esa liga.';

grant execute on function public.cancelar_cromo(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- reiniciar_resultados_jornada: al borrar los puntos, los cromos vuelven
-- a estar en juego para el siguiente escrutinio.
-- Parte de la versión de 0020.
-- ---------------------------------------------------------------------
create or replace function public.reiniciar_resultados_jornada(
  p_liga_id         uuid,
  p_jornada_numero  int
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_jornada_id uuid;
  v_n          int;
begin
  if auth.uid() is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  if not public.fn_es_owner_liga(p_liga_id) then
    raise exception 'Solo el dueño del servidor puede reiniciar resultados'
      using errcode = 'PT403', detail = 'no_owner';
  end if;

  select j.id into v_jornada_id
    from public.jornadas j
   where j.liga_id = p_liga_id
     and j.numero = p_jornada_numero;

  if v_jornada_id is null then
    raise exception 'Jornada no encontrada en este servidor'
      using errcode = 'PT404', detail = 'jornada_no_encontrada';
  end if;

  delete from public.puntuaciones
   where partido_id in (
     select p.id from public.partidos p where p.jornada_id = v_jornada_id
   );

  update public.cromos_aplicados
     set estado = 'activo'
   where jornada_id = v_jornada_id
     and estado in ('resuelto', 'anulado');

  update public.partidos
     set goles_local     = null,
         goles_visitante = null,
         resultado_at    = null,
         estado          = 'programado',
         updated_at      = now()
   where jornada_id = v_jornada_id;

  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

comment on function public.reiniciar_resultados_jornada(uuid, int) is
  'Dueño: borra resultados y puntos de una jornada; conserva pronósticos y reactiva los cromos.';

grant execute on function public.reiniciar_resultados_jornada(uuid, int)
  to authenticated;

-- ---------------------------------------------------------------------
-- Cromos en juego de una jornada para el usuario actual: lo que ha
-- lanzado y los ataques que ha recibido.
-- ---------------------------------------------------------------------
create or replace function public.fn_mis_cromos_jornada(
  p_liga_id uuid,
  p_jornada int
)
returns table (
  aplicado_id  uuid,
  cromo_codigo text,
  cromo_nombre text,
  tipo         text,
  estado       text,
  partido_id   uuid,
  local        text,
  visitante    text,
  fecha_inicio timestamptz,
  bloqueado    boolean,
  es_emisor    boolean,
  emisor_nombre   text,
  objetivo_nombre text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid        uuid := auth.uid();
  v_jornada_id uuid;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  if not exists (
    select 1 from public.liga_participantes lp
     where lp.liga_id = p_liga_id and lp.user_id = v_uid
  ) then
    raise exception 'No perteneces a este servidor'
      using errcode = 'PT403', detail = 'no_inscrito';
  end if;

  select j.id into v_jornada_id
    from public.jornadas j
   where j.liga_id = p_liga_id
     and j.numero = p_jornada;

  if v_jornada_id is null then
    return;
  end if;

  return query
  select
    ca.id,
    c.codigo,
    c.nombre,
    ca.tipo::text,
    ca.estado::text,
    p.id,
    el.nombre::text,
    ev.nombre::text,
    p.fecha_inicio,
    (
      p.estado <> 'suspendido'
      and now() >= (p.fecha_inicio - public.fn_margen_timelock())
    ),
    (ca.emisor_user_id = v_uid),
    pe.nombre::text,
    po.nombre::text
  from public.cromos_aplicados ca
  join public.cromos c    on c.id  = ca.cromo_id
  join public.partidos p  on p.id  = ca.partido_id
  join public.equipos el  on el.id = p.equipo_local_id
  join public.equipos ev  on ev.id = p.equipo_visitante_id
  join public.perfiles pe on pe.id = ca.emisor_user_id
  left join public.perfiles po on po.id = ca.objetivo_user_id
  where ca.jornada_id = v_jornada_id
    and ca.estado <> 'reembolsado'
    and (ca.emisor_user_id = v_uid or ca.objetivo_user_id = v_uid)
  order by p.fecha_inicio, c.nombre;
end;
$$;

comment on function public.fn_mis_cromos_jornada(uuid, int) is
  'Cromos de la jornada en los que el usuario está implicado como emisor u objetivo.';

grant execute on function public.fn_mis_cromos_jornada(uuid, int) to authenticated;
