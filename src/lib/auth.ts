import { createServerClient, hasSupabaseEnv } from "@/lib/supabase/server";

export async function getSessionUser() {
  if (!hasSupabaseEnv()) return null;

  try {
    const supabase = await createServerClient();
    if (!supabase) return null;

    const {
      data: { user },
      error,
    } = await supabase.auth.getUser();

    if (error) return null;
    return user;
  } catch {
    return null;
  }
}
