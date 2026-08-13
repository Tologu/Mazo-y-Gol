import { sessionHasExpired } from "@/lib/session";
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

    if (error || !user) return null;

    if (sessionHasExpired(user.last_sign_in_at)) {
      await supabase.auth.signOut();
      return null;
    }

    return user;
  } catch {
    return null;
  }
}
