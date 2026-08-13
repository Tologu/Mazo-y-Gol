"use client";

import { createBrowserSupabaseClient } from "@/lib/supabase/client";
import type { ModoJuego, ServidorCreado } from "@/lib/types";

function mapRpcError(error: { message?: string; code?: string } | null): string {
  if (!error) return "Error desconocido.";
  const msg = error.message ?? "";
  if (msg.includes("PT401") || msg.toLowerCase().includes("not authenticated")) {
    return "Debes iniciar sesión primero.";
  }
  if (msg.includes("nombre_corto") || msg.includes("al menos 3")) {
    return "El nombre debe tener al menos 3 caracteres.";
  }
  if (msg.includes("codigo_invalido") || msg.includes("inválido")) {
    return "Código de invitación inválido.";
  }
  if (msg.includes("modo_invalido")) {
    return "Modo de juego inválido.";
  }
  if (msg.includes("cromos_deshabilitados")) {
    return "Esta porra es Clásica: los cromos están deshabilitados.";
  }
  if (msg.includes("sin_plantilla")) {
    return "Falta la plantilla de calendario en Supabase.";
  }
  return msg || "No se pudo completar la operación.";
}

export async function crearServidorClient(
  nombre: string,
  modoJuego: ModoJuego = "clasica",
): Promise<{ ok: true; data: ServidorCreado } | { ok: false; error: string }> {
  const supabase = createBrowserSupabaseClient();
  if (!supabase) {
    return { ok: false, error: "Supabase no configurado." };
  }

  const { data, error } = await supabase.rpc("crear_servidor", {
    p_nombre: nombre.trim(),
    p_modo_juego: modoJuego,
  });

  if (error) {
    return { ok: false, error: mapRpcError(error) };
  }

  return { ok: true, data: data as ServidorCreado };
}

export async function unirseServidorClient(
  codigo: string,
): Promise<{ ok: true; data: ServidorCreado } | { ok: false; error: string }> {
  const supabase = createBrowserSupabaseClient();
  if (!supabase) {
    return { ok: false, error: "Supabase no configurado." };
  }

  const { data, error } = await supabase.rpc("unirse_servidor", {
    p_codigo: codigo.trim().toUpperCase(),
  });

  if (error) {
    return { ok: false, error: mapRpcError(error) };
  }

  return { ok: true, data: data as ServidorCreado };
}

export async function setLigaActivaClient(
  ligaId: string,
): Promise<{ ok: true; slug: string } | { ok: false; error: string }> {
  const supabase = createBrowserSupabaseClient();
  if (!supabase) {
    return { ok: false, error: "Supabase no configurado." };
  }

  const { data, error } = await supabase.rpc("set_liga_activa", {
    p_liga_id: ligaId,
  });

  if (error) {
    return { ok: false, error: mapRpcError(error) };
  }

  const slug = (data as { slug?: string } | null)?.slug;
  if (!slug) {
    return { ok: false, error: "No se pudo activar el servidor." };
  }

  return { ok: true, slug };
}
