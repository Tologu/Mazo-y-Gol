import { createServerClient } from "@supabase/ssr";
import type { CookieOptions } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { normalizeAppOrigin, safeNextPath } from "@/lib/app-url";

type CookieToSet = { name: string; value: string; options?: CookieOptions };

export async function GET(request: NextRequest) {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get("code");
  const next = safeNextPath(requestUrl.searchParams.get("next"));
  const origin = normalizeAppOrigin(requestUrl.origin);

  // Supabase envía error_code (p. ej. otp_expired) cuando el enlace no es válido.
  const errorCode = requestUrl.searchParams.get("error_code");
  if (errorCode) {
    const reason = errorCode === "otp_expired" ? "caducado" : "auth";
    return NextResponse.redirect(`${origin}/?error=${reason}`);
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!code || !url || !key) {
    return NextResponse.redirect(`${origin}/?error=auth`);
  }

  const redirectTo = `${origin}${next}`;
  const response = NextResponse.redirect(redirectTo);

  const supabase = createServerClient(url, key, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet: CookieToSet[]) {
        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, options);
        });
      },
    },
  });

  const { error } = await supabase.auth.exchangeCodeForSession(code);
  if (error) {
    console.error("Supabase auth callback failed:", error.message);
    const reason = error.message.toLowerCase().includes("code verifier")
      ? "verificador"
      : "auth";
    return NextResponse.redirect(`${origin}/?error=${reason}`);
  }

  response.cookies.set("recovery_pending", "", {
    path: "/",
    maxAge: 0,
  });

  return response;
}
