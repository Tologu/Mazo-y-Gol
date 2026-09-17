import { redirect } from "next/navigation";
import { getSessionUser } from "@/lib/auth";
import { resolvePostLoginPath } from "@/lib/servers";
import { hasSupabaseEnv } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function EntrarPage() {
  if (!hasSupabaseEnv()) {
    redirect("/");
  }

  const user = await getSessionUser();
  if (!user) {
    redirect("/");
  }

  redirect(await resolvePostLoginPath());
}
