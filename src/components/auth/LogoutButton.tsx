"use client";

import { useRouter } from "next/navigation";
import { createBrowserSupabaseClient } from "@/lib/supabase/client";

export function LogoutButton() {
  const router = useRouter();

  async function handleLogout() {
    const supabase = createBrowserSupabaseClient();
    if (supabase) {
      await supabase.auth.signOut();
    }
    router.push("/");
    router.refresh();
  }

  return (
    <button
      type="button"
      className="tve-nav-item tve-nav-item--button"
      onClick={handleLogout}
    >
      <span className="tve-nav-key tve-block--blue" />
      <span className="tve-nav-text">Salir</span>
    </button>
  );
}
