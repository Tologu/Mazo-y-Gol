-- Permisos de lectura para el frontend (anon / authenticated)
grant select on public.v_partidos_calendario to anon, authenticated;
grant select on public.v_pronosticos_detalle to anon, authenticated;
grant select on public.v_puntuaciones_detalle to anon, authenticated;
grant execute on function public.fn_clasificacion_porra(uuid) to anon, authenticated;
