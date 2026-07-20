import { redirect } from "next/navigation";
import { Suspense } from "react";
import { IntroHero } from "@/components/auth/IntroHero";
import { LoginPanel } from "@/components/auth/LoginPanel";
import { hasSupabaseEnv } from "@/lib/supabase/server";
import { getSessionUser } from "@/lib/auth";

export const dynamic = "force-dynamic";

export default async function IntroPage() {
  if (hasSupabaseEnv()) {
    const user = await getSessionUser();
    if (user) {
      redirect("/clasificacion");
    }
  }

  const demo = !hasSupabaseEnv();

  return (
    <div className="intro-screen">
      <div className="intro-page">
        <IntroHero />
        <Suspense
          fallback={
            <section className="intro-panel">
              <p className="intro-note tve-green">Cargando acceso...</p>
            </section>
          }
        >
          <LoginPanel demo={demo} />
        </Suspense>
        <footer className="intro-footer">
          <div className="tve-footer-bar">MAZO Y GOL . . . . 001</div>
        </footer>
      </div>
    </div>
  );
}
