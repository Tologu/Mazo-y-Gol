-- =====================================================================
-- 0026_abrir_pronosticos_jornada.sql
-- El owner puede abrir pronósticos de UNA jornada concreta sin abrir
-- las anteriores (casos de partidos adelantados).
-- =====================================================================

alter table public.jornadas
  add column if not exists pronosticos_abiertos_at timestamptz;

comment on column public.jornadas.pronosticos_abiertos_at is
  'Si no es null, el admin abrió esta jornada a pronósticos de forma manual (no abre las anteriores).';

-- Abierta por secuencia (anterior cerrada) O por apertura forzada del admin.
create or replace function public.fn_jornada_ya_abierta(p_jornada_id uuid)
returns boolean
language sql
stable
as $$
  select coalesce(
    (
      select j.pronosticos_abiertos_at is not null
      from public.jornadas j
      where j.id = p_jornada_id
    ),
    false
  )
  or coalesce(
    now() >= (
      public.fn_fecha_apertura_jornada(p_jornada_id)
      - public.fn_margen_timelock()
    ),
    true
  );
$$;

comment on function public.fn_jornada_ya_abierta(uuid) is
  'True si ya se puede pronosticar: anterior cerrada, jornada 1, o apertura forzada por admin.';

-- Vista: fecha_apertura null si forzada (UI la trata como ya abierta).
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
  case
    when j.pronosticos_abiertos_at is not null then null
    else prev.fecha_apertura
  end as fecha_apertura,
  (
    (
      j.pronosticos_abiertos_at is not null
      or prev.fecha_apertura is null
      or now() >= (prev.fecha_apertura - public.fn_margen_timelock())
    )
    and now() < (p.fecha_inicio - public.fn_margen_timelock())
  ) as abierta,
  (j.pronosticos_abiertos_at is not null) as apertura_forzada
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

-- Owner: abrir solo esta jornada (las anteriores no se tocan).
create or replace function public.abrir_pronosticos_jornada(
  p_liga_id        uuid,
  p_jornada_numero int
)
returns public.jornadas
language plpgsql
security definer
set search_path = public
as $$
declare
  v_jornada public.jornadas%rowtype;
begin
  if auth.uid() is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  if not public.fn_es_owner_liga(p_liga_id) then
    raise exception 'Solo el dueño del servidor puede abrir pronósticos'
      using errcode = 'PT403', detail = 'no_owner';
  end if;

  select * into v_jornada
  from public.jornadas j
  where j.liga_id = p_liga_id
    and j.numero = p_jornada_numero
  for update;

  if not found then
    raise exception 'Jornada no encontrada'
      using errcode = 'PT404', detail = 'jornada_no_encontrada';
  end if;

  if v_jornada.pronosticos_abiertos_at is not null then
    return v_jornada;
  end if;

  update public.jornadas
     set pronosticos_abiertos_at = now()
   where id = v_jornada.id
   returning * into v_jornada;

  return v_jornada;
end;
$$;

comment on function public.abrir_pronosticos_jornada(uuid, int) is
  'Owner: abre pronósticos de una jornada sin abrir las anteriores.';

grant execute on function public.abrir_pronosticos_jornada(uuid, int)
  to authenticated;
