-- 0038: las RPC de la app dejan de ser públicas.
-- En 0037 se revocó el permiso a anon, pero Postgres concede EXECUTE a
-- PUBLIC al crear la función y anon lo heredaba igualmente. Aquí se corta
-- por PUBLIC y se concede solo a authenticated.

do $$
declare
  v_firma text;
begin
  foreach v_firma in array array[
    'fn_clasificacion_porra(uuid)',
    'fn_mis_servidores()',
    'crear_servidor(text, text)',
    'unirse_servidor(text)',
    'set_liga_activa(uuid)',
    'guardar_pronostico(uuid, smallint, smallint)',
    'fn_pronosticos_jugador(uuid, integer, uuid)',
    'abrir_pronosticos_jornada(uuid, integer)',
    'usar_cromo(uuid, uuid, uuid)',
    'comprar_cromo(uuid, uuid)',
    'cancelar_cromo(uuid)',
    'fn_mi_mazo(uuid)',
    'fn_mis_cromos_jornada(uuid, integer)',
    'fn_saldo_liga(uuid)',
    'fn_mis_movimientos(uuid, integer)',
    'crear_jugador_bot(uuid, text)',
    'eliminar_jugador_bot(uuid, uuid)',
    'generar_pronosticos_bots(uuid, integer)',
    'registrar_resultado_liga(uuid, uuid, smallint, smallint)',
    'suspender_partido_liga(uuid, uuid)',
    'reiniciar_resultados_jornada(uuid, integer)'
  ]
  loop
    execute format('revoke execute on function public.%s from public, anon', v_firma);
    execute format('grant  execute on function public.%s to authenticated', v_firma);
  end loop;
end;
$$;

-- Las internas de 0037 tampoco deben volver por la puerta de PUBLIC.
revoke execute on function public.fn_escrutar_partido_interno(uuid)              from public;
revoke execute on function public.fn_escrutar_partido(uuid)                      from public;
revoke execute on function public.fn_escrutar_jornada(uuid)                      from public;
revoke execute on function public.fn_aplicar_cromos_partido(uuid, uuid, integer) from public;
revoke execute on function public.fn_premiar_partido(uuid)                       from public;
revoke execute on function public.fn_reembolsar_cromos_partido(uuid)             from public;
revoke execute on function public.fn_repartir_mazo_inicial(uuid, uuid)           from public;
revoke execute on function public.fn_clonar_calendario_plantilla(uuid)           from public;
revoke execute on function public.registrar_resultado(uuid, smallint, smallint, boolean) from public;
revoke execute on function public.marcar_partido_suspendido(uuid)                from public;
