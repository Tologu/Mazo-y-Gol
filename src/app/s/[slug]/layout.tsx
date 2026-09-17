import { redirect } from "next/navigation";
import { getSessionUser } from "@/lib/auth";
import { reclamarLoginDiario } from "@/lib/data";
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

  const loginDiario =
    liga.modo_juego === "mazo_y_gol"
      ? await reclamarLoginDiario(liga.id)
      : { concedido: false, cantidad: 0 };

  return (
    <>
      {loginDiario.concedido ? (
        <p className="tve-login-diario tve-green">
          Has cobrado {loginDiario.cantidad} monedas por entrar hoy.
        </p>
      ) : null}
      {children}
    </>
  );
}
