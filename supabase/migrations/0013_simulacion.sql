-- =====================================================================
-- 0013_simulacion.sql
-- Simulación para probar la clasificación: jugadores bot, pronósticos
-- aleatorios y registro manual de resultados por el DUEÑO del servidor.
--
-- Aplicar después de 0012_servidores.sql (Supabase SQL Editor o CLI).
--
-- Piezas:
--   • perfiles.es_bot                → marca jugadores ficticios
--   • fn_es_owner_liga               → helper de autorización por liga
--   • fn_escrutar_partido_interno    → escrutinio sin check de admin
--     (fn_escrutar_partido se redefine para delegar en él)
--   • crear_jugador_bot              → alta de bot (auth.users + perfil + inscripción)
--   • eliminar_jugador_bot           → baja de bot (cascada borra pronósticos/puntos)
--   • generar_pronosticos_bots       → pronósticos aleatorios de una jornada
--   • registrar_resultado_liga       → marcador manual + escrutinio (dueño)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Columna: marcar bots
-- ---------------------------------------------------------------------
alter table public.perfiles
  add column if not exists es_bot boolean not null default false;

comment on column public.perfiles.es_bot is
  'Jugador ficticio de simulación creado por el dueño de un servidor.';

-- ---------------------------------------------------------------------
-- Helper: ¿es el usuario autenticado dueño de la liga?
-- ---------------------------------------------------------------------
create or replace function public.fn_es_owner_liga(p_liga_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.ligas l
    where l.id = p_liga_id
      and l.owner_id = auth.uid()
      and l.es_plantilla = false
  );
$$;

comment on function public.fn_es_owner_liga is
  'True si auth.uid() es owner de la liga (y no es plantilla).';

-- ---------------------------------------------------------------------
-- Escrutinio interno (sin check de admin).
-- Lógica extraída de fn_escrutar_partido (0006); la versión pública
-- mantiene el check de admin y delega aquí.
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

    insert into public.puntuaciones (
      user_id, partido_id, jornada_id,
      puntos_base, acierto_exacto, acierto_signo,
      puntos_finales, detalle
    ) values (
      v_row.user_id, p_partido_id, v_partido.jornada_id,
      v_calc.puntos_base, v_calc.acierto_exacto, v_calc.acierto_signo,
      v_calc.puntos_base,  -- sin cromos aún
      jsonb_build_object(
        'fase', 'base',
        'pronostico', jsonb_build_object('local', v_row.goles_local, 'visitante', v_row.goles_visitante),
        'resultado',  jsonb_build_object('local', v_partido.goles_local, 'visitante', v_partido.goles_visitante),
        'signo_pronostico', public.fn_signo_resultado(v_row.goles_local, v_row.goles_visitante),
        'signo_real',       public.fn_signo_resultado(v_partido.goles_local, v_partido.goles_visitante)
      )
    )
    on conflict (user_id, partido_id) do update set
      puntos_base     = excluded.puntos_base,
      acierto_exacto  = excluded.acierto_exacto,
      acierto_signo   = excluded.acierto_signo,
      puntos_finales  = excluded.puntos_base,
      detalle         = excluded.detalle;

    v_insertados := v_insertados + 1;
  end loop;

  return v_insertados;
end;
$$;

comment on function public.fn_escrutar_partido_interno is
  'Escrutinio de un partido sin control de acceso. Solo para uso desde RPCs que ya validan permisos.';

-- Redefinir la versión pública: mismo contrato, delega en la interna.
create or replace function public.fn_escrutar_partido(p_partido_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.es_admin() then
    raise exception 'Solo administradores pueden escrutar partidos'
      using errcode = 'PT403';
  end if;

  return public.fn_escrutar_partido_interno(p_partido_id);
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: crear_jugador_bot (dueño de la liga)
-- Crea un usuario dummy en auth.users (sin contraseña utilizable);
-- el trigger tg_crear_perfil genera el perfil y aquí se marca es_bot.
-- ---------------------------------------------------------------------
create or replace function public.crear_jugador_bot(
  p_liga_id uuid,
  p_nombre  text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid      uuid := auth.uid();
  v_nombre   text := trim(p_nombre);
  v_bot_id   uuid := gen_random_uuid();
  v_username text;
  v_email    text;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  if not public.fn_es_owner_liga(p_liga_id) then
    raise exception 'Solo el dueño del servidor puede añadir bots'
      using errcode = 'PT403', detail = 'no_owner';
  end if;

  if v_nombre is null or length(v_nombre) < 3 then
    raise exception 'El nombre del bot debe tener al menos 3 caracteres'
      using errcode = 'PT400', detail = 'nombre_corto';
  end if;

  if length(v_nombre) > 40 then
    raise exception 'Nombre demasiado largo' using errcode = 'PT400';
  end if;

  v_username := 'bot_' || left(replace(v_bot_id::text, '-', ''), 8);
  v_email    := v_username || '@bots.mazoygol.local';

  -- Usuario dummy: email confirmado, sin contraseña utilizable.
  -- Los campos de token van como '' (no null) para no romper GoTrue.
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, recovery_token, email_change, email_change_token_new
  ) values (
    '00000000-0000-0000-0000-000000000000',
    v_bot_id,
    'authenticated',
    'authenticated',
    v_email,
    '',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('username', v_username, 'nombre', v_nombre),
    now(),
    now(),
    '', '', '', ''
  );

  update public.perfiles
     set es_bot = true
   where id = v_bot_id;

  insert into public.liga_participantes (liga_id, user_id)
  values (p_liga_id, v_bot_id)
  on conflict do nothing;

  return jsonb_build_object(
    'user_id', v_bot_id,
    'username', v_username,
    'nombre', v_nombre
  );
end;
$$;

comment on function public.crear_jugador_bot is
  'Dueño del servidor: crea un jugador ficticio (bot) y lo inscribe en la liga.';

-- ---------------------------------------------------------------------
-- RPC: eliminar_jugador_bot (dueño de la liga)
-- Borra el usuario de auth.users; la cascada elimina perfil,
-- pronósticos, puntuaciones e inscripciones.
-- ---------------------------------------------------------------------
create or replace function public.eliminar_jugador_bot(
  p_liga_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  if not public.fn_es_owner_liga(p_liga_id) then
    raise exception 'Solo el dueño del servidor puede eliminar bots'
      using errcode = 'PT403', detail = 'no_owner';
  end if;

  if not exists (
    select 1
    from public.perfiles pe
    join public.liga_participantes lp
      on lp.user_id = pe.id and lp.liga_id = p_liga_id
    where pe.id = p_user_id
      and pe.es_bot = true
  ) then
    raise exception 'El jugador no es un bot de este servidor'
      using errcode = 'PT404', detail = 'bot_no_encontrado';
  end if;

  delete from auth.users where id = p_user_id;
end;
$$;

comment on function public.eliminar_jugador_bot is
  'Dueño del servidor: elimina un bot y todos sus datos (cascada).';

-- ---------------------------------------------------------------------
-- RPC: generar_pronosticos_bots (dueño de la liga)
-- Pronósticos aleatorios (goles 0–4 ponderados) para todos los bots
-- de la liga en los partidos de la jornada sin resultado.
-- ---------------------------------------------------------------------
create or replace function public.generar_pronosticos_bots(
  p_liga_id         uuid,
  p_jornada_numero  int
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  -- Distribución realista: 0 y 1 goles más probables que 3 o 4.
  v_dist       int[] := array[0,0,0,0,0,1,1,1,1,1,1,1,2,2,2,2,2,3,3,4];
  v_jornada_id uuid;
  v_bot        record;
  v_partido    record;
  v_count      int := 0;
begin
  if auth.uid() is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  if not public.fn_es_owner_liga(p_liga_id) then
    raise exception 'Solo el dueño del servidor puede generar pronósticos'
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

  for v_bot in
    select pe.id
      from public.perfiles pe
      join public.liga_participantes lp
        on lp.user_id = pe.id and lp.liga_id = p_liga_id
     where pe.es_bot = true
  loop
    for v_partido in
      select p.id
        from public.partidos p
       where p.jornada_id = v_jornada_id
         and p.estado <> 'suspendido'
         and p.goles_local is null
         and p.goles_visitante is null
    loop
      insert into public.pronosticos (user_id, partido_id, goles_local, goles_visitante)
      values (
        v_bot.id,
        v_partido.id,
        v_dist[1 + floor(random() * array_length(v_dist, 1))::int],
        v_dist[1 + floor(random() * array_length(v_dist, 1))::int]
      )
      on conflict (user_id, partido_id) do update set
        goles_local     = excluded.goles_local,
        goles_visitante = excluded.goles_visitante,
        updated_at      = now();

      v_count := v_count + 1;
    end loop;
  end loop;

  return v_count;
end;
$$;

comment on function public.generar_pronosticos_bots is
  'Dueño del servidor: pronósticos aleatorios de todos los bots para una jornada (solo partidos sin resultado).';

-- ---------------------------------------------------------------------
-- RPC: registrar_resultado_liga (dueño de la liga)
-- Como registrar_resultado (admin) pero limitado a partidos de la
-- liga propia. Escruta al instante.
-- ---------------------------------------------------------------------
create or replace function public.registrar_resultado_liga(
  p_liga_id         uuid,
  p_partido_id      uuid,
  p_goles_local     smallint,
  p_goles_visitante smallint
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
    raise exception 'Solo el dueño del servidor puede registrar resultados'
      using errcode = 'PT403', detail = 'no_owner';
  end if;

  if p_goles_local is null or p_goles_visitante is null
     or p_goles_local < 0 or p_goles_visitante < 0 then
    raise exception 'Marcador inválido' using errcode = 'PT400';
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

  update public.partidos
     set goles_local     = p_goles_local,
         goles_visitante = p_goles_visitante,
         estado          = 'finalizado',
         resultado_at    = now(),
         updated_at      = now()
   where id = p_partido_id
  returning * into v_partido;

  perform public.fn_escrutar_partido_interno(p_partido_id);

  return v_partido;
end;
$$;

comment on function public.registrar_resultado_liga is
  'Dueño del servidor: marcador manual de un partido de su liga + escrutinio inmediato (5/2/0).';

-- ---------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------
grant execute on function public.fn_es_owner_liga(uuid) to authenticated;
grant execute on function public.crear_jugador_bot(uuid, text) to authenticated;
grant execute on function public.eliminar_jugador_bot(uuid, uuid) to authenticated;
grant execute on function public.generar_pronosticos_bots(uuid, int) to authenticated;
grant execute on function public.registrar_resultado_liga(uuid, uuid, smallint, smallint) to authenticated;

-- El escrutinio interno no se expone al cliente.
revoke execute on function public.fn_escrutar_partido_interno(uuid) from anon, authenticated;
