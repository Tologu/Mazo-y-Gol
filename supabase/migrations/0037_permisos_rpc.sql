-- 0037: quita de la API REST las funciones que no debería poder llamar nadie
-- y fija el search_path de los helpers que quedaban sueltos.

-- ---------------------------------------------------------------------
-- Internas del escrutinio y del reparto. Son security definer y algunas
-- no comprueban nada porque siempre se llaman desde otra RPC; expuestas
-- en /rest/v1/rpc/ cualquiera podía repartirse cromos o monedas.
-- ---------------------------------------------------------------------
revoke execute on function public.fn_escrutar_partido_interno(uuid)                  from public, anon, authenticated;
revoke execute on function public.fn_escrutar_partido(uuid)                          from public, anon, authenticated;
revoke execute on function public.fn_escrutar_jornada(uuid)                          from public, anon, authenticated;
revoke execute on function public.fn_aplicar_cromos_partido(uuid, uuid, integer)     from public, anon, authenticated;
revoke execute on function public.fn_premiar_partido(uuid)                           from public, anon, authenticated;
revoke execute on function public.fn_reembolsar_cromos_partido(uuid)                 from public, anon, authenticated;
revoke execute on function public.fn_repartir_mazo_inicial(uuid, uuid)               from public, anon, authenticated;
revoke execute on function public.fn_clonar_calendario_plantilla(uuid)               from public, anon, authenticated;
revoke execute on function public.fn_monedas_bienvenida()                            from public, anon, authenticated;
revoke execute on function public.fn_premio_por_acierto(boolean, boolean)            from public, anon, authenticated;

-- Versiones globales de admin: la app usa las variantes _liga, con dueño.
revoke execute on function public.registrar_resultado(uuid, smallint, smallint, boolean) from public, anon, authenticated;
revoke execute on function public.marcar_partido_suspendido(uuid)                        from public, anon, authenticated;
revoke execute on function public.rls_auto_enable()                                      from public, anon, authenticated;

-- Funciones de trigger: se disparan desde la tabla, no se llaman a mano.
revoke execute on function public.tg_crear_perfil()                    from public, anon, authenticated;
revoke execute on function public.tg_set_updated_at()                  from public, anon, authenticated;
revoke execute on function public.tg_equipo_unico_por_jornada()        from public, anon, authenticated;
revoke execute on function public.tg_validar_cupo_partidos_jornada()   from public, anon, authenticated;

-- Cálculo interno de puntos y ranking auxiliar (la app usa fn_clasificacion_porra).
revoke execute on function public.fn_clasificacion(uuid)                              from public, anon, authenticated;
revoke execute on function public.fn_posicion_usuario(uuid, uuid)                      from public, anon, authenticated;
revoke execute on function public.fn_ataque_permitido(uuid, uuid, uuid)                from public, anon, authenticated;
revoke execute on function public.fn_puntos_base_partido(integer, integer, integer, integer) from public, anon, authenticated;
revoke execute on function public.fn_signo_resultado(integer, integer)                 from public, anon, authenticated;
revoke execute on function public.fn_reglas_puntuacion()                               from public, anon, authenticated;
revoke execute on function public.fn_slugify(text)                                     from public, anon, authenticated;
revoke execute on function public.fn_slug_unico(text)                                  from public, anon, authenticated;
revoke execute on function public.fn_generar_codigo_invite()                            from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- RPC de la app: solo con sesión. Todas validan auth.uid() dentro, pero
-- sin sesión no tienen nada que hacer.
-- ---------------------------------------------------------------------
revoke execute on function public.fn_clasificacion_porra(uuid)                    from anon;
revoke execute on function public.fn_mis_servidores()                             from anon;
revoke execute on function public.crear_servidor(text, text)                      from anon;
revoke execute on function public.unirse_servidor(text)                           from anon;
revoke execute on function public.set_liga_activa(uuid)                           from anon;
revoke execute on function public.guardar_pronostico(uuid, smallint, smallint)    from anon;
revoke execute on function public.fn_pronosticos_jugador(uuid, integer, uuid)     from anon;
revoke execute on function public.abrir_pronosticos_jornada(uuid, integer)        from anon;
revoke execute on function public.usar_cromo(uuid, uuid, uuid)                    from anon;
revoke execute on function public.comprar_cromo(uuid, uuid)                       from anon;
revoke execute on function public.cancelar_cromo(uuid)                            from anon;
revoke execute on function public.fn_mi_mazo(uuid)                                from anon;
revoke execute on function public.fn_mis_cromos_jornada(uuid, integer)            from anon;
revoke execute on function public.fn_saldo_liga(uuid)                             from anon;
revoke execute on function public.fn_mis_movimientos(uuid, integer)               from anon;
revoke execute on function public.crear_jugador_bot(uuid, text)                   from anon;
revoke execute on function public.eliminar_jugador_bot(uuid, uuid)                from anon;
revoke execute on function public.generar_pronosticos_bots(uuid, integer)         from anon;
revoke execute on function public.registrar_resultado_liga(uuid, uuid, smallint, smallint) from anon;
revoke execute on function public.suspender_partido_liga(uuid, uuid)              from anon;
revoke execute on function public.reiniciar_resultados_jornada(uuid, integer)     from anon;

-- ---------------------------------------------------------------------
-- search_path fijo: sin esto un search_path manipulado podría hacer que
-- la función resuelva otra tabla con el mismo nombre.
-- Se quedan fuera es_admin, fn_margen_timelock, fn_jornada_ya_abierta,
-- fn_participa_liga y compañía porque ya lo traen desde su migración.
-- ---------------------------------------------------------------------
alter function public.tg_set_updated_at()                                        set search_path = public;
alter function public.tg_validar_cupo_partidos_jornada()                         set search_path = public;
alter function public.tg_equipo_unico_por_jornada()                              set search_path = public;
alter function public.fn_clasificacion(uuid)                                     set search_path = public;
alter function public.fn_posicion_usuario(uuid, uuid)                            set search_path = public;
alter function public.fn_ataque_permitido(uuid, uuid, uuid)                      set search_path = public;
alter function public.fn_margen_timelock()                                       set search_path = public;
alter function public.fn_reglas_puntuacion()                                     set search_path = public;
alter function public.fn_signo_resultado(integer, integer)                       set search_path = public;
alter function public.fn_puntos_base_partido(integer, integer, integer, integer) set search_path = public;
alter function public.fn_nombre_visible(text, citext)                            set search_path = public;
alter function public.fn_partido_exige_pronostico(public.partidos)               set search_path = public;
alter function public.fn_slugify(text)                                           set search_path = public;
alter function public.fn_slug_unico(text)                                        set search_path = public;
alter function public.fn_generar_codigo_invite()                                 set search_path = public;
alter function public.fn_fecha_apertura_jornada(uuid)                            set search_path = public;
alter function public.fn_jornada_ya_abierta(uuid)                                set search_path = public;
