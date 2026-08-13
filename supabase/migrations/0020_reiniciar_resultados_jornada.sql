-- =====================================================================
-- 0020_reiniciar_resultados_jornada.sql
-- Dueño del servidor: borra marcadores oficiales + puntuaciones de una
-- jornada. Conserva pronósticos y cromos. Partidos → programado.
-- =====================================================================

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
  'Dueño: borra resultados y puntos de una jornada; conserva pronósticos.';

grant execute on function public.reiniciar_resultados_jornada(uuid, int)
  to authenticated;
