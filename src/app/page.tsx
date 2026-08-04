import { redirect } from "next/navigation";
import { cookies } from "next/headers";
import { Suspense } from "react";
import { IntroHero } from "@/components/auth/IntroHero";
import { LoginPanel } from "@/components/auth/LoginPanel";
import { hasSupabaseEnv } from "@/lib/supabase/server";
import { getSessionUser } from "@/lib/auth";
import { resolvePostLoginPath } from "@/lib/servers";

export const dynamic = "force-dynamic";

export default async function IntroPage({
  searchParams,
}: {
  searchParams: Promise<{
    msg?: string;
    code?: string;
  }>;
}) {
  const params = await searchParams;

  // Supabase puede volver a la Site URL si no acepta el redirect_to completo.
  // Rescatamos ese código y lo enviamos al callback que crea la sesión.
  if (params.code) {
    const cookieStore = await cookies();
    const isRecovery = cookieStore.get("recovery_pending")?.value === "1";
    const callbackParams = new URLSearchParams({
      code: params.code,
      next: isRecovery ? "/auth/restablecer" : "/entrar",
    });
    redirect(`/auth/callback?${callbackParams.toString()}`);
  }

  const demo = !hasSupabaseEnv();

  if (hasSupabaseEnv()) {
    const user = await getSessionUser();
    if (user) {
      redirect(await resolvePostLoginPath());
    }
  }

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
