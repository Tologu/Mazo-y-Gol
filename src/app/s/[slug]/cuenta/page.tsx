import {
  TeletextFooter,
  TeletextHeader,
  TeletextNav,
} from "@/components/teletext/TeletextShell";
import { MiUsuarioPanel } from "@/components/auth/MiUsuarioPanel";
import { getSessionUser } from "@/lib/auth";
import { getLigaBySlug } from "@/lib/servers";
import { createServerClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export const dynamic = "force-dynamic";

export default async function CuentaPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;

  const liga = await getLigaBySlug(slug);
  if (!liga) redirect("/");

  const user = await getSessionUser();
  if (!user) {
    redirect(`/?next=${encodeURIComponent(`/s/${slug}/cuenta`)}`);
  }

  const supabase = await createServerClient();
  const { data: perfil } = supabase
    ? await supabase
        .from("perfiles")
        .select("nombre, username")
        .eq("id", user.id)
        .maybeSingle()
    : { data: null };

  return (
    <div className="tve-page-wrap">
      <div className="tve-page">
        <TeletextHeader
          seccion={`${liga.nombre.toUpperCase()} · MI USUARIO`}
          pagina="600"
        />
        <main className="tve-main">
          <MiUsuarioPanel
            nombreActual={perfil?.nombre ?? ""}
            username={perfil?.username ?? ""}
            email={user.email ?? ""}
          />
        </main>
        <TeletextFooter pagina="600" />
      </div>
      <TeletextNav
        active="cuenta"
        slug={slug}
        showAdmin={liga.es_owner}
        showCromos={liga.modo_juego === "mazo_y_gol"}
      />
    </div>
  );
}
