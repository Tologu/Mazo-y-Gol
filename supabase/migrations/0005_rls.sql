-- =====================================================================
-- 0005_rls.sql
-- Row Level Security. Filosofía:
--   * Lectura: bastante abierta entre usuarios autenticados (clasificación,
--     partidos, catálogo de cromos, pronósticos de otros una vez bloqueado el partido).
--   * Escritura: SOLO el dueño, y SOLO por las vías controladas.
--   * Las acciones sensibles (gastar monedas, jugar cromos, escrutar) NO se hacen
--     con INSERT/UPDATE directos: se canalizan por RPC 'security definer'.
-- =====================================================================

-- Helper: ¿el usuario actual es admin?
create or replace function public.es_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select es_admin from public.perfiles where id = auth.uid()), false);
$$;

-- ---------------------------------------------------------------------
-- Activar RLS en todas las tablas
-- ---------------------------------------------------------------------
alter table public.perfiles              enable row level security;
alter table public.ligas                 enable row level security;
alter table public.liga_participantes    enable row level security;
alter table public.equipos               enable row level security;
alter table public.jornadas              enable row level security;
alter table public.partidos              enable row level security;
alter table public.pronosticos           enable row level security;
alter table public.puntuaciones          enable row level security;
alter table public.cromos                enable row level security;
alter table public.inventarios           enable row level security;
alter table public.transacciones_monedas enable row level security;
alter table public.cromos_aplicados      enable row level security;

-- ---------------------------------------------------------------------
-- PERFILES: todos ven perfiles; cada uno edita SOLO datos no sensibles del suyo.
-- (monedas/es_admin no deben tocarse por el cliente -> se controla por columnas
--  desde la app o por RPC; aquí evitamos al menos el cambio de otros).
-- ---------------------------------------------------------------------
create policy perfiles_select on public.perfiles
  for select using (true);

create policy perfiles_update_propio on public.perfiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- ---------------------------------------------------------------------
-- LIGAS / EQUIPOS / JORNADAS / PARTIDOS: lectura para autenticados;
-- escritura solo admin.
-- ---------------------------------------------------------------------
create policy ligas_select on public.ligas for select using (true);
create policy ligas_admin  on public.ligas for all
  using (public.es_admin()) with check (public.es_admin());

create policy equipos_select on public.equipos for select using (true);
create policy equipos_admin  on public.equipos for all
  using (public.es_admin()) with check (public.es_admin());

create policy jornadas_select on public.jornadas for select using (true);
create policy jornadas_admin  on public.jornadas for all
  using (public.es_admin()) with check (public.es_admin());

create policy partidos_select on public.partidos for select using (true);
create policy partidos_admin  on public.partidos for all
  using (public.es_admin()) with check (public.es_admin());

-- ---------------------------------------------------------------------
-- INSCRIPCIONES: el usuario ve las suyas y puede unirse; admin todo.
-- ---------------------------------------------------------------------
create policy participantes_select on public.liga_participantes
  for select using (true);
create policy participantes_join on public.liga_participantes
  for insert with check (user_id = auth.uid());
create policy participantes_admin on public.liga_participantes
  for all using (public.es_admin()) with check (public.es_admin());

-- ---------------------------------------------------------------------
-- PRONÓSTICOS
--  * El dueño ve siempre los suyos.
--  * Los de otros solo son visibles cuando el partido YA está bloqueado
--    (time-lock), para no revelar pronósticos antes de empezar.
--  * Inserción/edición solo del dueño y SOLO si el partido no está bloqueado.
-- ---------------------------------------------------------------------
create policy pronosticos_select_propio on public.pronosticos
  for select using (user_id = auth.uid());

create policy pronosticos_select_ajenos_si_bloqueado on public.pronosticos
  for select using (
    exists (
      select 1 from public.partidos p
      where p.id = pronosticos.partido_id
        and now() >= (p.fecha_inicio - public.fn_margen_timelock())
    )
  );

create policy pronosticos_insert_propio on public.pronosticos
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.partidos p
      where p.id = partido_id
        and now() < (p.fecha_inicio - public.fn_margen_timelock())
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
    )
  );

-- ---------------------------------------------------------------------
-- PUNTUACIONES: lectura pública (clasificación); escritura solo backend/admin.
-- (El escrutinio se hará por RPC security definer en la siguiente fase.)
-- ---------------------------------------------------------------------
create policy puntuaciones_select on public.puntuaciones for select using (true);
create policy puntuaciones_admin  on public.puntuaciones for all
  using (public.es_admin()) with check (public.es_admin());

-- ---------------------------------------------------------------------
-- CROMOS (catálogo): lectura para todos; escritura solo admin.
-- ---------------------------------------------------------------------
create policy cromos_select on public.cromos for select using (true);
create policy cromos_admin  on public.cromos for all
  using (public.es_admin()) with check (public.es_admin());

-- ---------------------------------------------------------------------
-- INVENTARIOS: el usuario ve SOLO el suyo. NO puede modificarlo directamente
-- (se modifica vía RPC usar_cromo / comprar_cromo). Admin puede ajustar.
-- ---------------------------------------------------------------------
create policy inventarios_select_propio on public.inventarios
  for select using (user_id = auth.uid());
create policy inventarios_admin on public.inventarios
  for all using (public.es_admin()) with check (public.es_admin());

-- ---------------------------------------------------------------------
-- TRANSACCIONES: el usuario ve SOLO las suyas. Sin escritura directa.
-- ---------------------------------------------------------------------
create policy transacciones_select_propio on public.transacciones_monedas
  for select using (user_id = auth.uid());
create policy transacciones_admin on public.transacciones_monedas
  for all using (public.es_admin()) with check (public.es_admin());

-- ---------------------------------------------------------------------
-- CROMOS APLICADOS
--  * El emisor ve lo que ha jugado.
--  * El objetivo ve los ataques que ha recibido (para enterarse del sabotaje).
--  * Sin INSERT/UPDATE directo: SOLO vía RPC usar_cromo (security definer).
-- ---------------------------------------------------------------------
create policy aplicados_select_implicado on public.cromos_aplicados
  for select using (
    emisor_user_id = auth.uid() or objetivo_user_id = auth.uid()
  );
create policy aplicados_admin on public.cromos_aplicados
  for all using (public.es_admin()) with check (public.es_admin());

-- NOTA: como usar_cromo es SECURITY DEFINER, sus INSERT/UPDATE saltan RLS,
-- por lo que NO definimos policy de insert para usuarios normales: la única
-- forma de escribir en inventarios/cromos_aplicados es a través del RPC.
