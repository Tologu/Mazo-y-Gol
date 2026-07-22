import { redirect } from "next/navigation";
import Link from "next/link";
import { IntroHero } from "@/components/auth/IntroHero";
import { ServerPicker } from "@/components/auth/ServerPicker";
import { getSessionUser } from "@/lib/auth";
import { listMisServidores } from "@/lib/servers";
import { hasSupabaseEnv } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function ServidoresPage() {
  if (!hasSupabaseEnv()) {
    redirect("/s/demo/clasificacion");
  }

  const user = await getSessionUser();
  if (!user) {
    redirect("/");
  }

  const servidores = await listMisServidores();

  return (
    <div className="intro-screen">
      <div className="intro-page">
        <IntroHero />
        <ServerPicker servidores={servidores} />
        <p className="intro-note">
          <Link href="/?msg=gestionar" className="tve-cyan">
            ← Volver a inicio (crear / unirse)
          </Link>
        </p>
        <footer className="intro-footer">
          <div className="tve-footer-bar">MAZO Y GOL . . . . 003</div>
        </footer>
      </div>
    </div>
  );
}
