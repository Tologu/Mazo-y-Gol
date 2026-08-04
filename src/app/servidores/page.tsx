import { redirect } from "next/navigation";
import { IntroHero } from "@/components/auth/IntroHero";
import { ServerActionsPanel } from "@/components/auth/ServerActionsPanel";
import { ServerPicker } from "@/components/auth/ServerPicker";
import { getSessionUser } from "@/lib/auth";
import { listMisServidores } from "@/lib/servers";
import { hasSupabaseEnv } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function ServidoresPage() {
  if (!hasSupabaseEnv()) {
    redirect("/");
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
        {servidores.length > 0 && <ServerPicker servidores={servidores} />}
        <ServerActionsPanel />
        <footer className="intro-footer">
          <div className="tve-footer-bar">MAZO Y GOL . . . . 003</div>
        </footer>
      </div>
    </div>
  );
}
