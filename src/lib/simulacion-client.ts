"use client";

import { createBrowserSupabaseClient } from "@/lib/supabase/client";
import type { BotJugador } from "@/lib/types";

type RpcResult<T> = { ok: true; data: T } | { ok: false; error: string };

function mapRpcError(error: { message?: string; code?: string } | null): string {
  if (!error) return "Error desconocido.";
  const msg = error.message ?? "";
  if (msg.includes("PT401") || msg.toLowerCase().includes("not authenticated")) {
    return "Debes iniciar sesión primero.";
  }
  if (msg.includes("no_owner")) {
    return "Solo el dueño del servidor puede hacer esto.";
  }
  if (msg.includes("nombre_corto") || msg.includes("al menos 3")) {
    return "El nombre debe tener al menos 3 caracteres.";
  }
  if (msg.includes("bot_no_encontrado")) {
    return "Ese jugador no es un bot de este servidor.";
  }
  if (msg.includes("jornada_no_encontrada")) {
    return "Jornada no encontrada en este servidor.";
  }
  if (msg.includes("partido_ajeno")) {
    return "El partido no pertenece a este servidor.";
  }
  if (msg.includes("partido_suspendido") || msg.includes("suspendido")) {
    return "El partido está suspendido.";
  }
  if (msg.includes("Marcador inválido")) {
    return "Marcador inválido.";
  }
  return msg || "No se pudo completar la operación.";
}

export async function crearBotClient(
  ligaId: string,
  nombre: string,
): Promise<RpcResult<BotJugador>> {
  const supabase = createBrowserSupabaseClient();
  if (!supabase) return { ok: false, error: "Supabase no configurado." };

  const { data, error } = await supabase.rpc("crear_jugador_bot", {
    p_liga_id: ligaId,
    p_nombre: nombre.trim(),
  });

  if (error) return { ok: false, error: mapRpcError(error) };
  return { ok: true, data: data as BotJugador };
}

export async function eliminarBotClient(
  ligaId: string,
  userId: string,
): Promise<RpcResult<null>> {
  const supabase = createBrowserSupabaseClient();
  if (!supabase) return { ok: false, error: "Supabase no configurado." };

  const { error } = await supabase.rpc("eliminar_jugador_bot", {
    p_liga_id: ligaId,
    p_user_id: userId,
  });

  if (error) return { ok: false, error: mapRpcError(error) };
  return { ok: true, data: null };
}

export async function generarPronosticosClient(
  ligaId: string,
  jornadaNumero: number,
): Promise<RpcResult<number>> {
  const supabase = createBrowserSupabaseClient();
  if (!supabase) return { ok: false, error: "Supabase no configurado." };

  const { data, error } = await supabase.rpc("generar_pronosticos_bots", {
    p_liga_id: ligaId,
    p_jornada_numero: jornadaNumero,
  });

  if (error) return { ok: false, error: mapRpcError(error) };
  return { ok: true, data: (data as number) ?? 0 };
}

export async function registrarResultadoClient(
  ligaId: string,
  partidoId: string,
  golesLocal: number,
  golesVisitante: number,
): Promise<RpcResult<null>> {
  const supabase = createBrowserSupabaseClient();
  if (!supabase) return { ok: false, error: "Supabase no configurado." };

  const { error } = await supabase.rpc("registrar_resultado_liga", {
    p_liga_id: ligaId,
    p_partido_id: partidoId,
    p_goles_local: golesLocal,
    p_goles_visitante: golesVisitante,
  });

  if (error) return { ok: false, error: mapRpcError(error) };
  return { ok: true, data: null };
}

export async function suspenderPartidoClient(
  ligaId: string,
  partidoId: string,
): Promise<RpcResult<null>> {
  const supabase = createBrowserSupabaseClient();
  if (!supabase) return { ok: false, error: "Supabase no configurado." };

  const { error } = await supabase.rpc("suspender_partido_liga", {
    p_liga_id: ligaId,
    p_partido_id: partidoId,
  });

  if (error) return { ok: false, error: mapRpcError(error) };
  return { ok: true, data: null };
}
