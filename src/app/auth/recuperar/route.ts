import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";
import { normalizeAppOrigin } from "@/lib/app-url";

export async function POST(request: NextRequest) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!url || !key) {
    return NextResponse.json(
      { error: "Supabase no configurado." },
      { status: 500 },
    );
  }

  const body = (await request.json().catch(() => null)) as {
    email?: unknown;
  } | null;
  const email = typeof body?.email === "string" ? body.email.trim() : "";

  if (!email) {
    return NextResponse.json(
      { error: "Introduce tu correo." },
      { status: 400 },
    );
  }

  // Recovery usa flujo implícito para no depender del verificador PKCE:
  // Gmail puede abrir el enlace sin la cookie donde se guardó ese verificador.
  const supabase = createClient(url, key, {
    auth: {
      flowType: "implicit",
      persistSession: false,
    },
  });

  const appOrigin = normalizeAppOrigin(
    process.env.NEXT_PUBLIC_APP_URL ?? request.nextUrl.origin,
  );
  const redirectTo = `${appOrigin}/auth/restablecer`;

  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo,
  });

  if (error) {
    console.error("Supabase password recovery failed:", error.message);
    return NextResponse.json(
      { error: error.message },
      { status: 400 },
    );
  }

  const response = NextResponse.json({ ok: true });
  response.cookies.set("recovery_pending", "", {
    path: "/",
    maxAge: 0,
  });
  return response;
}
