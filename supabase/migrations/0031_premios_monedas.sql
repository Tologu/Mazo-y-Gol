-- =====================================================================
-- 0031_premios_monedas.sql
-- Los aciertos dan monedas para poder comprar cromos en la tienda.
--
-- Se premia al escrutar cada partido. Como el escrutinio puede repetirse
-- (registrar_resultado, reiniciar_resultados_jornada), primero se
-- revierten los premios anteriores de ese partido y luego se reparten
-- de nuevo. Así el saldo no se infla al recalcular.
-- =====================================================================

create or replace function public.fn_premio_por_acierto(
  p_exacto boolean,
  p_signo  boolean
)
returns bigint
language sql
immutable
as $$
  select case
    when p_exacto then 10::bigint
    when p_signo  then 4::bigint
    else 0::bigint
  end;
$$;

comment on function public.fn_premio_por_acierto(boolean, boolean) is
  'Monedas que reparte un partido: 10 por marcador exacto, 4 por signo.';

create or replace function public.fn_premiar_partido(p_partido_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_liga_id uuid;
  v_row     record;
  v_premio  bigint;
  v_saldo   bigint;
begin
  select j.liga_id into v_liga_id
    from public.partidos p
    join public.jornadas j on j.id = p.jornada_id
   where p.id = p_partido_id;

  if v_liga_id is null then
    return;
  end if;

  -- Revertir lo repartido en escrutinios anteriores de este partido.
  for v_row in
    select t.user_id, sum(t.cantidad) as total
      from public.transacciones_monedas t
     where t.liga_id = v_liga_id
       and t.tipo = 'premio_jornada'
       and t.referencia->>'partido_id' = p_partido_id::text
     group by t.user_id
  loop
    update public.liga_participantes
       set monedas = greatest(0, monedas - v_row.total)
     where liga_id = v_liga_id
       and user_id = v_row.user_id;
  end loop;

  delete from public.transacciones_monedas t
   where t.liga_id = v_liga_id
     and t.tipo = 'premio_jornada'
     and t.referencia->>'partido_id' = p_partido_id::text;

  -- Repartir según las puntuaciones recién calculadas.
  for v_row in
    select pu.user_id, pu.acierto_exacto, pu.acierto_signo
      from public.puntuaciones pu
     where pu.partido_id = p_partido_id
  loop
    v_premio := public.fn_premio_por_acierto(
      v_row.acierto_exacto, v_row.acierto_signo
    );

    if v_premio <= 0 then
      continue;
    end if;

    update public.liga_participantes
       set monedas = monedas + v_premio
     where liga_id = v_liga_id
       and user_id = v_row.user_id
    returning monedas into v_saldo;

    if not found then
      continue;
    end if;

    insert into public.transacciones_monedas (
      user_id, liga_id, tipo, cantidad, saldo_resultante, referencia
    ) values (
      v_row.user_id, v_liga_id, 'premio_jornada', v_premio, v_saldo,
      jsonb_build_object(
        'partido_id', p_partido_id,
        'motivo', case when v_row.acierto_exacto
                       then 'Acierto exacto'
                       else 'Acierto de signo' end
      )
    );
  end loop;
end;
$$;

comment on function public.fn_premiar_partido(uuid) is
  'Reparte monedas por los aciertos de un partido. Idempotente: revierte lo anterior antes de repartir.';

-- ---------------------------------------------------------------------
-- Enganchar el premio al final del escrutinio.
-- Parte de la versión de 0029 (cromos incluidos).
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

  update public.cromos_aplicados
     set estado = 'activo'
   where partido_id = p_partido_id
     and estado in ('resuelto', 'anulado');

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

  update public.cromos_aplicados
     set estado = 'resuelto'
   where partido_id = p_partido_id
     and estado = 'activo';

  perform public.fn_premiar_partido(p_partido_id);

  return v_insertados;
end;
$$;

comment on function public.fn_escrutar_partido_interno is
  'Escrutinio de un partido con cromos y reparto de monedas. Sin control de acceso.';

-- ---------------------------------------------------------------------
-- Al borrar los resultados de una jornada también se retiran las
-- monedas que repartió, para que el saldo vuelva a su sitio.
-- Parte de la versión de 0029.
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
  v_row        record;
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

  for v_row in
    select p.id as partido_id
      from public.partidos p
     where p.jornada_id = v_jornada_id
  loop
    delete from public.puntuaciones where partido_id = v_row.partido_id;
    perform public.fn_premiar_partido(v_row.partido_id);
  end loop;

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
  'Dueño: borra resultados, puntos y premios de una jornada; conserva pronósticos y reactiva los cromos.';

grant execute on function public.reiniciar_resultados_jornada(uuid, int)
  to authenticated;
