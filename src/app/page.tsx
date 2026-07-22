import { redirect } from "next/navigation";
import { Suspense } from "react";
import { IntroHero } from "@/components/auth/IntroHero";
import { LoginPanel } from "@/components/auth/LoginPanel";
import { ServerActionsPanel } from "@/components/auth/ServerActionsPanel";
import { hasSupabaseEnv } from "@/lib/supabase/server";
import { getSessionUser } from "@/lib/auth";
import { resolvePostLoginPath } from "@/lib/servers";

export const dynamic = "force-dynamic";

export default async function IntroPage({
  searchParams,
}: {
  searchParams: Promise<{ msg?: string }>;
}) {
  const params = await searchParams;
  const demo = !hasSupabaseEnv();
  let loggedIn = false;

  if (hasSupabaseEnv()) {
    const user = await getSessionUser();
    if (user) {
      loggedIn = true;
      // Si ya tiene servidor activo, entra directo (salvo que quiera crear/unir)
      if (params.msg !== "sin-servidor" && params.msg !== "gestionar") {
        const dest = await resolvePostLoginPath();
        if (!dest.startsWith("/?")) {
          redirect(dest);
        }
      }
    }
  }

  return (
    <div className="intro-screen">
      <div className="intro-page">
        <IntroHero />
        {params.msg === "sin-servidor" && (
          <p className="intro-note tve-yellow">
            No tienes servidor. Crea uno o únete con un código.
          </p>
        )}
        <Suspense
          fallback={
            <section className="intro-panel">
              <p className="intro-note tve-green">Cargando acceso...</p>
            </section>
          }
        >
          {!loggedIn && <LoginPanel demo={demo} />}
        </Suspense>
        {loggedIn && (
          <p className="intro-note tve-green">
            Sesión iniciada — crea o únete a un servidor
          </p>
        )}
        <ServerActionsPanel demo={demo} loggedIn={loggedIn || demo} />
        <footer className="intro-footer">
          <div className="tve-footer-bar">MAZO Y GOL . . . . 001</div>
        </footer>
      </div>
    </div>
  );
}
