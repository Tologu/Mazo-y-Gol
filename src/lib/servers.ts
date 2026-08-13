import { createServerClient } from "@/lib/supabase/server";
import { isModoJuego } from "@/lib/modo-juego";
import type { BotJugador, LigaContexto, ModoJuego, ServidorResumen } from "@/lib/types";

function normalizeModo(value: unknown): ModoJuego {
  return isModoJuego(value) ? value : "clasica";
}

export async function listMisServidores(): Promise<ServidorResumen[]> {
  const supabase = await createServerClient();
  if (!supabase) return [];

  const { data, error } = await supabase.rpc("fn_mis_servidores");
  if (error || !data) return [];
  return (data as ServidorResumen[]).map((s) => ({
    ...s,
    modo_juego: normalizeModo(s.modo_juego),
  }));
}

/** Tras login siempre a la pestaña Servidores (elegir, crear o unirse). */
export async function resolvePostLoginPath(): Promise<string> {
  return "/servidores";
}

export async function getLigaBySlug(
  slug: string,
): Promise<LigaContexto | null> {
  const supabase = await createServerClient();
  if (!supabase) return null;

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: liga, error } = await supabase
    .from("ligas")
    .select(
      "id, slug, nombre, codigo_invite, owner_id, es_plantilla, activa, modo_juego",
    )
    .eq("slug", slug)
    .eq("es_plantilla", false)
    .eq("activa", true)
    .maybeSingle();

  if (error || !liga) return null;

  const { data: inscrito } = await supabase
    .from("liga_participantes")
    .select("user_id")
    .eq("liga_id", liga.id)
    .eq("user_id", user.id)
    .maybeSingle();

  if (!inscrito) return null;

  const esOwner = liga.owner_id === user.id;

  return {
    id: liga.id,
    slug: liga.slug,
    nombre: liga.nombre,
    codigo_invite: esOwner ? liga.codigo_invite : null,
    es_owner: esOwner,
    modo_juego: normalizeModo(liga.modo_juego),
  };
}

export async function getBotsLiga(ligaId: string): Promise<BotJugador[]> {
  const supabase = await createServerClient();
  if (!supabase) return [];

  const { data, error } = await supabase
    .from("liga_participantes")
    .select("user_id, perfiles!inner(username, nombre, es_bot)")
    .eq("liga_id", ligaId)
    .eq("perfiles.es_bot", true);

  if (error || !data) return [];

  return data.map((row) => {
    const perfil = row.perfiles as unknown as {
      username: string;
      nombre: string;
    };
    return {
      user_id: row.user_id as string,
      username: perfil.username,
      nombre: perfil.nombre,
    };
  });
}

export async function setLigaActiva(ligaId: string): Promise<boolean> {
  const supabase = await createServerClient();
  if (!supabase) return false;

  const { error } = await supabase.rpc("set_liga_activa", {
    p_liga_id: ligaId,
  });
  return !error;
}
