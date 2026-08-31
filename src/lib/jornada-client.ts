"use client";

import { createBrowserSupabaseClient } from "@/lib/supabase/client";

type RpcResult = { ok: true } | { ok: false; error: string };

function mapError(error: { message?: string; details?: string } | null): string {
  const message = `${error?.message ?? ""} ${error?.details ?? ""}`;
  if (message.includes("no_owner")) {
    return "Solo el dueño del servidor puede abrir pronósticos.";
  }
  if (message.includes("jornada_no_encontrada")) {
    return "Jornada no encontrada.";
  }
  if (message.includes("PT401") || message.toLowerCase().includes("not authenticated")) {
    return "Debes iniciar sesión.";
  }
  return error?.message || "No se pudo abrir la jornada.";
}

export async function abrirPronosticosJornadaClient(
  ligaId: string,
  jornadaNumero: number,
): Promise<RpcResult> {
  const supabase = createBrowserSupabaseClient();
  if (!supabase) return { ok: false, error: "Supabase no configurado." };

  const { error } = await supabase.rpc("abrir_pronosticos_jornada", {
    p_liga_id: ligaId,
    p_jornada_numero: jornadaNumero,
  });

  if (error) return { ok: false, error: mapError(error) };
  return { ok: true };
}
