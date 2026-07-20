import { redirect } from "next/navigation";
import { getSessionUser } from "@/lib/auth";
import { hasSupabaseEnv } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function PorraLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  if (hasSupabaseEnv()) {
    const user = await getSessionUser();
    if (!user) {
      redirect("/");
    }
  }

  return children;
}
