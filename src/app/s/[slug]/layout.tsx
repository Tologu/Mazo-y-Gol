import { redirect } from "next/navigation";
import { getSessionUser } from "@/lib/auth";
import { syncPerfilDesdeAuth } from "@/lib/perfil";
import { getLigaBySlug, setLigaActiva } from "@/lib/servers";
import { hasSupabaseEnv } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function ServerLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;

  if (!hasSupabaseEnv()) {
    redirect("/");
  }

  const user = await getSessionUser();
  if (!user) {
    redirect(`/?next=${encodeURIComponent(`/s/${slug}/clasificacion`)}`);
  }
  await syncPerfilDesdeAuth();

  const liga = await getLigaBySlug(slug);
  if (!liga) {
    redirect("/servidores");
  }

  await setLigaActiva(liga.id);

  return children;
}
