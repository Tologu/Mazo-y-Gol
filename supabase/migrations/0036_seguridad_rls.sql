-- 0036: cierra los huecos de lectura y escritura que quedaban abiertos

-- ---------------------------------------------------------------------
-- Helpers (security definer para que no se muerdan con las policies)
-- ---------------------------------------------------------------------
create or replace function public.fn_participa_liga(p_liga_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.liga_participantes lp
    where lp.liga_id = p_liga_id and lp.user_id = auth.uid()
  );
$$;

comment on function public.fn_participa_liga(uuid) is
  'True si el usuario autenticado está inscrito en esa liga.';

create or replace function public.fn_comparte_liga(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.liga_participantes mios
    join public.liga_participantes otros on otros.liga_id = mios.liga_id
    where mios.user_id = auth.uid()
      and otros.user_id = p_user_id
  );
$$;

comment on function public.fn_comparte_liga(uuid) is
  'True si ese usuario juega en alguna liga del usuario autenticado.';

grant execute on function public.fn_participa_liga(uuid) to authenticated;
grant execute on function public.fn_comparte_liga(uuid)  to authenticated;

-- ---------------------------------------------------------------------
-- PERFILES
--  * Escritura: solo nombre/username/avatar de la propia fila. Con el
--    UPDATE completo, cualquiera podía ponerse es_admin = true o subirse
--    las monedas desde la consola del navegador.
--  * Lectura: yo, quien comparte servidor conmigo, y el admin.
-- ---------------------------------------------------------------------
revoke update on public.perfiles from anon, authenticated;
grant update (nombre, username, avatar_url) on public.perfiles to authenticated;

drop policy if exists perfiles_select on public.perfiles;
drop policy if exists perfiles_select_visible on public.perfiles;
create policy perfiles_select_visible on public.perfiles
  for select using (
    id = auth.uid()
    or public.es_admin()
    or public.fn_comparte_liga(id)
  );

-- ---------------------------------------------------------------------
-- LIGA_PARTICIPANTES: solo las plantillas de mis servidores.
-- ---------------------------------------------------------------------
drop policy if exists participantes_select on public.liga_participantes;
drop policy if exists participantes_select_liga on public.liga_participantes;
create policy participantes_select_liga on public.liga_participantes
  for select using (
    user_id = auth.uid()
    or public.es_admin()
    or public.fn_participa_liga(liga_id)
  );

-- ---------------------------------------------------------------------
-- PUNTUACIONES: la clasificación es de la liga, no global.
-- ---------------------------------------------------------------------
drop policy if exists puntuaciones_select on public.puntuaciones;
drop policy if exists puntuaciones_select_liga on public.puntuaciones;
create policy puntuaciones_select_liga on public.puntuaciones
  for select using (
    user_id = auth.uid()
    or public.es_admin()
    or exists (
      select 1 from public.jornadas j
      where j.id = puntuaciones.jornada_id
        and public.fn_participa_liga(j.liga_id)
    )
  );

-- ---------------------------------------------------------------------
-- PRONÓSTICOS AJENOS: además del time-lock, hay que compartir servidor.
-- Antes bastaba con que el partido estuviera bloqueado, así que se veían
-- los pronósticos de ligas ajenas.
-- ---------------------------------------------------------------------
drop policy if exists pronosticos_select_ajenos_si_bloqueado on public.pronosticos;
create policy pronosticos_select_ajenos_si_bloqueado on public.pronosticos
  for select using (
    exists (
      select 1
      from public.partidos p
      join public.jornadas j on j.id = p.jornada_id
      where p.id = pronosticos.partido_id
        and now() >= (p.fecha_inicio - public.fn_margen_timelock())
        and public.fn_participa_liga(j.liga_id)
    )
  );

-- ---------------------------------------------------------------------
-- VISTAS
--  * security_invoker: sin esto la vista consulta como su dueño y se
--    salta el RLS de las tablas de debajo.
--  * v_pronosticos_detalle y v_puntuaciones_detalle no las usa la app;
--    quedan solo para consultas manuales.
-- ---------------------------------------------------------------------
alter view public.v_partidos_calendario  set (security_invoker = true);
alter view public.v_stats_usuario        set (security_invoker = true);
alter view public.v_pronosticos_detalle  set (security_invoker = true);
alter view public.v_puntuaciones_detalle set (security_invoker = true);

revoke all on public.v_pronosticos_detalle  from anon, authenticated;
revoke all on public.v_puntuaciones_detalle from anon, authenticated;
revoke all on public.v_stats_usuario        from anon;
