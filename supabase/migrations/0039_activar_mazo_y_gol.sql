-- 0039: el dueño puede pasar un servidor Clásico a Mazo y Gol

create or replace function public.activar_mazo_y_gol(p_liga_id uuid)
returns public.ligas
language plpgsql
security definer
set search_path = public
as $$
declare
  v_liga public.ligas%rowtype;
  v_user uuid;
begin
  if auth.uid() is null then
    raise exception 'No autenticado' using errcode = 'PT401';
  end if;

  if not public.fn_es_owner_liga(p_liga_id) then
    raise exception 'Solo el dueño del servidor puede cambiar el modo'
      using errcode = 'PT403', detail = 'no_owner';
  end if;

  select * into v_liga from public.ligas where id = p_liga_id;
  if not found or v_liga.es_plantilla or not v_liga.activa then
    raise exception 'Servidor no encontrado' using errcode = 'PT404';
  end if;

  if v_liga.modo_juego = 'mazo_y_gol' then
    raise exception 'Este servidor ya es Mazo y Gol'
      using errcode = 'PT400', detail = 'ya_es_mazo_y_gol';
  end if;

  update public.ligas
     set modo_juego = 'mazo_y_gol'
   where id = p_liga_id
  returning * into v_liga;

  for v_user in
    select lp.user_id
      from public.liga_participantes lp
     where lp.liga_id = p_liga_id
  loop
    perform public.fn_repartir_mazo_inicial(p_liga_id, v_user);
  end loop;

  return v_liga;
end;
$$;

comment on function public.activar_mazo_y_gol(uuid) is
  'Dueño: pasa la porra de Clásica a Mazo y Gol y reparte mazo y monedas.';

revoke execute on function public.activar_mazo_y_gol(uuid) from public, anon;
grant execute on function public.activar_mazo_y_gol(uuid) to authenticated;
