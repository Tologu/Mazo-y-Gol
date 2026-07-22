import { redirect } from "next/navigation";

export const dynamic = "force-dynamic";

/** Compat: rutas antiguas → resolver servidor. */
export default function LegacyClasificacionRedirect() {
  redirect("/entrar");
}
