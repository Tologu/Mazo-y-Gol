"use client";

import { createBrowserSupabaseClient } from "@/lib/supabase/client";
import type { PronosticoAjeno } from "@/lib/types";

type GuardarPronosticoResult =
  | { ok: true }
  | { ok: false; error: string };

type VerPronosticosResult =
  | { ok: true; data: PronosticoAjeno[] }
  | { ok: false; error: string };

function mapError(error: { message?: string } | null): string {
  const message = error?.message ?? "";

  if (message.includes("time_lock")) {
    return "El partido ya está bloqueado para pronósticos.";
  }
  if (message.includes("partido_cerrado")) {
    return "El partido ya tiene resultado y no admite pronósticos.";
  }
  if (message.includes("no_inscrito")) {
    return "No perteneces a este servidor.";
  }
  if (message.includes("PT401")) {
    return "Debes iniciar sesión.";
  }

  return message || "No se pudo guardar el pronóstico.";
}

export async function guardarPronosticoClient(
  partidoId: string,
  golesLocal: number,
  golesVisitante: number,
): Promise<GuardarPronosticoResult> {
  const supabase = createBrowserSupabaseClient();
  if (!supabase) {
    return { ok: false, error: "Supabase no configurado." };
  }

  const { error } = await supabase.rpc("guardar_pronostico", {
    p_partido_id: partidoId,
    p_goles_local: golesLocal,
    p_goles_visitante: golesVisitante,
  });

  if (error) return { ok: false, error: mapError(error) };
  return { ok: true };
}

export async function verPronosticosJugadorClient(
  ligaId: string,
  jornada: number,
  userId: string,
): Promise<VerPronosticosResult> {
  const supabase = createBrowserSupabaseClient();
  if (!supabase) {
    return { ok: false, error: "Supabase no configurado." };
  }

  const { data, error } = await supabase.rpc("fn_pronosticos_jugador", {
    p_liga_id: ligaId,
    p_jornada: jornada,
    p_user_id: userId,
  });

  if (error) {
    const message = `${error.message ?? ""} ${error.details ?? ""}`;
    if (message.includes("pronosticos_incompletos") || message.includes("para ver los de otros")) {
      return {
        ok: false,
        error:
          "Completa primero tus pronósticos de la jornada para ver los de otros jugadores.",
      };
    }
    if (message.includes("objetivo_incompleto") || message.includes("no ha completado")) {
      return {
        ok: false,
        error: "Ese jugador aún no ha completado sus pronósticos de la jornada.",
      };
    }
    return { ok: false, error: mapError(error) };
  }

  return { ok: true, data: (data ?? []) as PronosticoAjeno[] };
}
