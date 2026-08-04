import { createServerClient } from "@/lib/supabase/server";
import type { User } from "@supabase/supabase-js";

function nombreDesdeMetadata(user: User): string | null {
  const meta = user.user_metadata ?? {};
  const nombreMeta =
    typeof meta.nombre === "string" ? meta.nombre.trim() : "";
  return nombreMeta || null;
}

/** Sincroniza perfiles.nombre con el metadata de Auth (campo nombre). */
export async function syncPerfilDesdeAuth(): Promise<void> {
  const supabase = await createServerClient();
  if (!supabase) return;

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return;

  const meta = user.user_metadata ?? {};
  const usernameMeta =
    typeof meta.username === "string" ? meta.username.trim().toLowerCase() : "";
  const nombreNuevo = nombreDesdeMetadata(user);

  const { data: perfil } = await supabase
    .from("perfiles")
    .select("nombre, username")
    .eq("id", user.id)
    .maybeSingle();

  const updates: { nombre?: string; username?: string } = {};

  if (usernameMeta && perfil?.username !== usernameMeta) {
    updates.username = usernameMeta;
  }

  if (nombreNuevo && perfil?.nombre !== nombreNuevo) {
    updates.nombre = nombreNuevo;
  }

  if (Object.keys(updates).length === 0) return;

  await supabase.from("perfiles").update(updates).eq("id", user.id);
}
