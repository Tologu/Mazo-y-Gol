"use client";

import { createBrowserSupabaseClient } from "@/lib/supabase/client";

type ActualizarNombreResult = { ok: true } | { ok: false; error: string };

/**
 * Cambia el nombre visible en la clasificación.
 * Actualiza Auth metadata y perfiles a la vez: el layout sincroniza
 * perfiles desde Auth, así que ambos deben quedar iguales.
 */
export async function actualizarNombreClient(
  nombre: string,
): Promise<ActualizarNombreResult> {
  const limpio = nombre.trim();
  if (limpio.length < 3) {
    return { ok: false, error: "El nombre debe tener al menos 3 caracteres." };
  }
  if (limpio.length > 40) {
    return { ok: false, error: "El nombre no puede superar 40 caracteres." };
  }

  const supabase = createBrowserSupabaseClient();
  if (!supabase) {
    return { ok: false, error: "Supabase no configurado." };
  }

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return { ok: false, error: "Debes iniciar sesión." };
  }

  const { error: authError } = await supabase.auth.updateUser({
    data: { nombre: limpio },
  });
  if (authError) {
    return { ok: false, error: authError.message };
  }

  const { error: perfilError } = await supabase
    .from("perfiles")
    .update({ nombre: limpio })
    .eq("id", user.id);
  if (perfilError) {
    return { ok: false, error: perfilError.message };
  }

  return { ok: true };
}
