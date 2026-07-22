import { redirect } from "next/navigation";
import { getSessionUser } from "@/lib/auth";
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
  const demoMode = !hasSupabaseEnv() || slug === "demo";

  if (!demoMode) {
    const user = await getSessionUser();
    if (!user) {
      redirect(`/?next=${encodeURIComponent(`/s/${slug}/clasificacion`)}`);
    }
  }

  const { liga } = await getLigaBySlug(slug);
  if (!liga) {
    redirect("/?msg=sin-servidor");
  }

  if (!demoMode && liga.id !== "demo") {
    await setLigaActiva(liga.id);
  }

  return children;
}
