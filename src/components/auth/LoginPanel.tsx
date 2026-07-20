"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";
import Link from "next/link";
import { createBrowserSupabaseClient } from "@/lib/supabase/client";

type Props = {
  demo?: boolean;
};

export function LoginPanel({ demo = false }: Props) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const next = searchParams.get("next") ?? "/clasificacion";
  const authError = searchParams.get("error");

  const [registerMode, setRegisterMode] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [nombre, setNombre] = useState("");
  const [username, setUsername] = useState("");
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<string | null>(
    authError === "auth" ? "No se pudo confirmar la sesión." : null,
  );

  async function handleLogin() {
    setMessage(null);
    if (demo) {
      setMessage("Configura .env.local para iniciar sesión real.");
      return;
    }
    if (!email || !password) {
      setMessage("Introduce email y contraseña.");
      return;
    }

    const supabase = createBrowserSupabaseClient();
    if (!supabase) {
      setMessage("Supabase no configurado.");
      return;
    }

    setLoading(true);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setLoading(false);

    if (error) {
      setMessage(error.message);
      return;
    }

    router.push(next);
    router.refresh();
  }

  async function handleRegister() {
    setMessage(null);
    if (demo) {
      setMessage("Configura .env.local para registrarte.");
      return;
    }
    if (!email || !password) {
      setMessage("Introduce email y contraseña.");
      return;
    }
    if (!username.trim() || username.trim().length < 3) {
      setMessage("El usuario debe tener al menos 3 caracteres.");
      setRegisterMode(true);
      return;
    }

    const supabase = createBrowserSupabaseClient();
    if (!supabase) {
      setMessage("Supabase no configurado.");
      return;
    }

    setLoading(true);
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          nombre: nombre.trim() || "Jugador",
          username: username.trim().toLowerCase(),
        },
        emailRedirectTo: `${window.location.origin}/auth/callback?next=${encodeURIComponent(next)}`,
      },
    });
    setLoading(false);

    if (error) {
      setMessage(error.message);
      return;
    }

    setMessage("Cuenta creada. Revisa tu email o inicia sesión.");
    setRegisterMode(false);
  }

  async function handleRegisterClick() {
    if (!registerMode) {
      setRegisterMode(true);
      setMessage("Completa el usuario y pulsa Registrarse.");
      return;
    }
    await handleRegister();
  }

  return (
    <section className="intro-panel">
      <div className="tve-colhead">
        <span>Acceso</span>
        <span>P001</span>
      </div>

      {demo && (
        <p className="intro-note tve-yellow">
          MODO DEMO — sin Supabase · usa los campos o entra directo
        </p>
      )}

      <div className="intro-form">
        {registerMode && (
          <>
            <label className="intro-field">
              <span className="intro-label tve-green">Nombre</span>
              <input
                type="text"
                autoComplete="name"
                value={nombre}
                onChange={(e) => setNombre(e.target.value)}
                placeholder="Tu nombre en la porra"
                maxLength={40}
              />
            </label>
            <label className="intro-field">
              <span className="intro-label tve-cyan">Usuario</span>
              <input
                type="text"
                autoComplete="username"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="min 3 caracteres"
                minLength={3}
                maxLength={20}
                pattern="[a-zA-Z0-9_]+"
              />
            </label>
          </>
        )}

        <label className="intro-field">
          <span className="intro-label tve-yellow">Correo</span>
          <input
            type="email"
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="tu@email.com"
          />
        </label>

        <label className="intro-field">
          <span className="intro-label tve-red">Contraseña</span>
          <input
            type="password"
            autoComplete={registerMode ? "new-password" : "current-password"}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="mínimo 6 caracteres"
            minLength={6}
          />
        </label>

        {message && <p className="intro-msg">{message}</p>}

        <div className="intro-actions">
          <button
            type="button"
            className="intro-btn intro-btn--login"
            onClick={handleLogin}
            disabled={loading}
          >
            {loading && !registerMode ? "Entrando..." : "Iniciar sesión"}
          </button>
          <button
            type="button"
            className="intro-btn intro-btn--register"
            onClick={handleRegisterClick}
            disabled={loading}
          >
            {loading && registerMode ? "Creando..." : "Registrarse"}
          </button>
        </div>

        {demo && (
          <Link href="/clasificacion" className="intro-btn intro-btn--demo">
            Entrar en demo (sin login)
          </Link>
        )}
      </div>
    </section>
  );
}
