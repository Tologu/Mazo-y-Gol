"use client";

import { createBrowserSupabaseClient } from "@/lib/supabase/client";

type CromoResult = { ok: true } | { ok: false; error: string };

function mapError(error: { message?: string; details?: string } | null): string {
  const message = `${error?.message ?? ""} ${error?.details ?? ""}`;

  if (message.includes("cromos_deshabilitados")) {
    return "Esta porra es Clásica: los cromos están deshabilitados.";
  }
  if (message.includes("sin_stock")) {
    return "No te queda ninguna carta de ese tipo.";
  }
  if (message.includes("time_lock")) {
    return "El partido ya está bloqueado: no admite cromos.";
  }
  if (message.includes("partido_cerrado")) {
    return "El partido ya tiene resultado.";
  }
  if (message.includes("jornada_no_abierta")) {
    return "Esta jornada se abre cuando cierre la anterior.";
  }
  if (message.includes("ya_recibio_ataque") || message.includes("uq_un_ataque_recibido_jornada")) {
    return "Ese jugador ya ha recibido un ataque esta jornada.";
  }
  if (message.includes("no_puedes_atacarte")) {
    return "No puedes atacarte a ti mismo.";
  }
  if (message.includes("usuario_no_clasificado")) {
    return "Aún no apareces en la clasificación: no puedes atacar.";
  }
  if (message.includes("objetivo_no_inscrito")) {
    return "Ese jugador no participa en este servidor.";
  }
  if (message.includes("no_inscrito")) {
    return "No perteneces a este servidor.";
  }
  if (message.includes("ataque_sin_objetivo")) {
    return "Elige contra quién lanzas el ataque.";
  }
  if (message.includes("bonificacion_con_objetivo")) {
    return "Una bonificación se juega sobre ti mismo, sin rival.";
  }
  if (message.includes("saldo_insuficiente")) {
    return "No tienes monedas suficientes para esa carta.";
  }
  if (message.includes("no_comprable") || message.includes("no_en_tienda_hoy")) {
    return "Esa carta no está en tu tienda de hoy.";
  }
  if (message.includes("cromo_resuelto")) {
    return "Ese cromo ya se ha resuelto y no se puede retirar.";
  }
  if (message.includes("no_es_tuyo")) {
    return "Solo puedes retirar tus propios cromos.";
  }
  if (message.includes("uq_bonif_unica_por_partido")) {
    return "Ya tienes esa bonificación equipada en ese partido.";
  }
  if (message.includes("PT401")) {
    return "Debes iniciar sesión.";
  }

  return error?.message || "No se pudo jugar el cromo.";
}

export async function usarCromoClient(
  cromoId: string,
  partidoId: string,
  objetivoUserId?: string | null,
): Promise<CromoResult> {
  const supabase = createBrowserSupabaseClient();
  if (!supabase) {
    return { ok: false, error: "Supabase no configurado." };
  }

  const { error } = await supabase.rpc("usar_cromo", {
    p_cromo_id: cromoId,
    p_partido_id: partidoId,
    p_objetivo_user_id: objetivoUserId ?? null,
  });

  if (error) return { ok: false, error: mapError(error) };
  return { ok: true };
}

export async function comprarCromoClient(
  cromoId: string,
  ligaId: string,
): Promise<CromoResult> {
  const supabase = createBrowserSupabaseClient();
  if (!supabase) {
    return { ok: false, error: "Supabase no configurado." };
  }

  const { error } = await supabase.rpc("comprar_cromo", {
    p_cromo_id: cromoId,
    p_liga_id: ligaId,
  });

  if (error) return { ok: false, error: mapError(error) };
  return { ok: true };
}

export async function cancelarCromoClient(
  aplicadoId: string,
): Promise<CromoResult> {
  const supabase = createBrowserSupabaseClient();
  if (!supabase) {
    return { ok: false, error: "Supabase no configurado." };
  }

  const { error } = await supabase.rpc("cancelar_cromo", {
    p_aplicado_id: aplicadoId,
  });

  if (error) return { ok: false, error: mapError(error) };
  return { ok: true };
}
