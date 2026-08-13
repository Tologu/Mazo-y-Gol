import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import type { CookieOptions } from "@supabase/ssr";
import { sessionHasExpired } from "@/lib/session";

type CookieToSet = { name: string; value: string; options?: CookieOptions };

export async function middleware(request: NextRequest) {
  const path = request.nextUrl.pathname;
  const isServerRoute = path.startsWith("/s/");
  const isServidores = path === "/servidores" || path === "/entrar";

  if (!isServerRoute && !isServidores) {
    return NextResponse.next();
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) {
    return NextResponse.redirect(new URL("/", request.url));
  }

  let response = NextResponse.next({ request });

  const supabase = createServerClient(url, key, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet: CookieToSet[]) {
        cookiesToSet.forEach(({ name, value }) => {
          request.cookies.set(name, value);
        });
        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, options);
        });
      },
    },
  });

  try {
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (user && sessionHasExpired(user.last_sign_in_at)) {
      await supabase.auth.signOut();
      const loginUrl = new URL("/", request.url);
      loginUrl.searchParams.set("error", "sesion");
      const redirect = NextResponse.redirect(loginUrl);
      response.cookies.getAll().forEach((cookie) => {
        redirect.cookies.set(cookie);
      });
      return redirect;
    }

    if (!user) {
      const loginUrl = new URL("/", request.url);
      loginUrl.searchParams.set("next", path);
      return NextResponse.redirect(loginUrl);
    }
  } catch {
    return NextResponse.next();
  }

  return response;
}

export const config = {
  matcher: ["/s/:path*", "/servidores", "/entrar", "/clasificacion", "/jornada"],
};
