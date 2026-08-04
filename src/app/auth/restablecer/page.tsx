import { Suspense } from "react";
import { ResetPasswordPanel } from "@/components/auth/ResetPasswordPanel";

export const dynamic = "force-dynamic";

export default function RestablecerPage() {
  return (
    <div className="intro-screen">
      <div className="intro-page">
        <Suspense
          fallback={
            <section className="intro-panel">
              <p className="intro-note tve-green">Cargando...</p>
            </section>
          }
        >
          <ResetPasswordPanel />
        </Suspense>
        <footer className="intro-footer">
          <div className="tve-footer-bar">MAZO Y GOL . . . . 002</div>
        </footer>
      </div>
    </div>
  );
}
