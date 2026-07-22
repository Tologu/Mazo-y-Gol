import { createServerClient } from "@/lib/supabase/server";
import type { LigaContexto, ServidorResumen } from "@/lib/types";

const DEMO_SERVIDOR: LigaContexto = {
  id: "demo",
  slug: "demo",
  nombre: "Servidor Demo",
  codigo_invite: "DEMO-0000",
  es_owner: true,
};

export async function listMisServidores(): Promise<ServidorResumen[]> {
  const supabase = await createServerClient();
  if (!supabase) return [];

  const { data, error } = await supabase.rpc("fn_mis_servidores");
  if (error || !data) return [];
  return data as ServidorResumen[];
}

export async function resolvePostLoginPath(): Promise<string> {
  const servidores = await listMisServidores();
  if (servidores.length === 0) {
    return "/?msg=sin-servidor";
  }

  const activo = servidores.find((s) => s.es_activa);
  if (activo?.slug) {
    return `/s/${activo.slug}/clasificacion`;
  }

  if (servidores.length === 1 && servidores[0].slug) {
    return `/s/${servidores[0].slug}/clasificacion`;
  }

  return "/servidores";
}

export async function getLigaBySlug(
  slug: string,
): Promise<{ liga: LigaContexto | null; demo: boolean }> {
  if (slug === "demo") {
    return { liga: DEMO_SERVIDOR, demo: true };
  }

  const supabase = await createServerClient();
  if (!supabase) {
    return { liga: DEMO_SERVIDOR, demo: true };
  }

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return { liga: null, demo: false };
  }

  const { data: liga, error } = await supabase
    .from("ligas")
    .select("id, slug, nombre, codigo_invite, owner_id, es_plantilla, activa")
    .eq("slug", slug)
    .eq("es_plantilla", false)
    .eq("activa", true)
    .maybeSingle();

  if (error || !liga) {
    return { liga: null, demo: false };
  }

  const { data: inscrito } = await supabase
    .from("liga_participantes")
    .select("user_id")
    .eq("liga_id", liga.id)
    .eq("user_id", user.id)
    .maybeSingle();

  if (!inscrito) {
    return { liga: null, demo: false };
  }

  const esOwner = liga.owner_id === user.id;

  return {
    liga: {
      id: liga.id,
      slug: liga.slug,
      nombre: liga.nombre,
      codigo_invite: esOwner ? liga.codigo_invite : null,
      es_owner: esOwner,
    },
    demo: false,
  };
}

export async function setLigaActiva(ligaId: string): Promise<boolean> {
  const supabase = await createServerClient();
  if (!supabase) return false;

  const { error } = await supabase.rpc("set_liga_activa", {
    p_liga_id: ligaId,
  });
  return !error;
}
