"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { PasswordToggleIcon } from "@/components/auth/PasswordToggleIcon";
import { getBrowserOrigin } from "@/lib/app-url";
import { createBrowserSupabaseClient } from "@/lib/supabase/client";

type Props = {
  demo?: boolean;
};

export function LoginPanel({ demo = false }: Props) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const next = searchParams.get("next") ?? "/servidores";
  const authError = searchParams.get("error");
  const statusMessage = searchParams.get("msg");

  const [registerMode, setRegisterMode] = useState(false);
  const [recoverMode, setRecoverMode] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [nombre, setNombre] = useState("");
  const [username, setUsername] = useState("");
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<string | null>(
    authError === "caducado"
      ? "El enlace del correo ha caducado o ya se usó. Solicita uno nuevo con «¿Olvidaste tu contraseña?»."
      : authError === "sesion"
        ? "La sesión ha caducado (8 horas). Vuelve a iniciar sesión."
      : authError === "verificador"
        ? "El enlace se abrió sin el verificador de seguridad. Solicita uno nuevo desde este navegador."
      : authError === "auth"
        ? "No se pudo confirmar la sesión. Vuelve a solicitar el enlace."
        : statusMessage === "contrasena-actualizada"
          ? "Contraseña actualizada. Inicia sesión con la contraseña nueva."
        : null,
  );

  useEffect(() => {
    const hash = window.location.hash;
    if (hash.includes("type=recovery") && hash.includes("access_token")) {
      window.location.replace(`/auth/restablecer${hash}`);
    }
  }, []);

  async function handleLogin() {
    setMessage(null);
    if (demo) {
      setMessage("Faltan variables de entorno de Supabase en el servidor.");
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
      setMessage("Faltan variables de entorno de Supabase en el servidor.");
      return;
    }
    if (!email || !password) {
      setMessage("Introduce email y contraseña.");
      return;
    }
    if (!nombre.trim() || nombre.trim().length < 3) {
      setMessage("El nombre debe tener al menos 3 caracteres (es lo que sale en la clasificación).");
      setRegisterMode(true);
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
          nombre: nombre.trim(),
          username: username.trim().toLowerCase(),
        },
        emailRedirectTo: `${getBrowserOrigin()}/auth/callback?next=${encodeURIComponent(next)}`,
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
      setRecoverMode(false);
      setRegisterMode(true);
      setMessage("Completa nombre, usuario y pulsa Registrarse.");
      return;
    }
    await handleRegister();
  }

  async function handleRecoverPassword() {
    setMessage(null);
    if (demo) {
      setMessage("Faltan variables de entorno de Supabase en el servidor.");
      return;
    }
    if (!email) {
      setMessage("Introduce tu correo.");
      return;
    }

    setLoading(true);
    try {
      const response = await fetch("/auth/recuperar", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });
      const result = (await response.json()) as {
        ok?: boolean;
        error?: string;
      };

      if (!response.ok) {
        setMessage(result.error ?? "No se pudo enviar el correo.");
        return;
      }

      setMessage(
        "Revisa tu correo. Te hemos enviado un enlace para restablecer la contraseña.",
      );
    } catch {
      setMessage("No se pudo conectar con el servidor. Inténtalo de nuevo.");
    } finally {
      setLoading(false);
    }
  }

  function openRecoverMode() {
    setRegisterMode(false);
    setRecoverMode(true);
    setShowPassword(false);
    setMessage("Introduce tu correo y te enviaremos un enlace.");
  }

  function backToLogin() {
    setRecoverMode(false);
    setRegisterMode(false);
    setMessage(null);
  }

  return (
    <section className="intro-panel">
      <div className="tve-colhead">
        <span>Acceso</span>
        <span>P001</span>
      </div>

      {demo && (
        <p className="intro-note tve-yellow">
          Falta configurar Supabase: añade NEXT_PUBLIC_SUPABASE_URL y
          NEXT_PUBLIC_SUPABASE_ANON_KEY en Vercel (Settings → Environment
          Variables) y vuelve a desplegar.
        </p>
      )}

      <div className="intro-form">
        {recoverMode && (
          <p className="intro-note tve-cyan">
            Te enviaremos un enlace al correo para elegir una contraseña nueva.
          </p>
        )}

        {registerMode && (
          <>
            <label className="intro-field">
              <span className="intro-label tve-green">Nombre</span>
              <input
                type="text"
                autoComplete="name"
                value={nombre}
                onChange={(e) => setNombre(e.target.value)}
                placeholder="Ej. SPECIAL ONE (sale en clasificación)"
                minLength={3}
                maxLength={40}
                required
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

        {!recoverMode && (
          <label className="intro-field intro-field--password">
            <span className="intro-label tve-red">Contraseña</span>
            <input
              type={showPassword ? "text" : "password"}
              autoComplete={registerMode ? "new-password" : "current-password"}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="mínimo 6 caracteres"
              minLength={6}
            />
            <button
              type="button"
              className="intro-password-toggle"
              onClick={() => setShowPassword((v) => !v)}
              aria-label={showPassword ? "Ocultar contraseña" : "Mostrar contraseña"}
              aria-pressed={showPassword}
            >
              <PasswordToggleIcon visible={showPassword} />
            </button>
          </label>
        )}

        {!recoverMode && !registerMode && !demo && (
          <button type="button" className="intro-link" onClick={openRecoverMode}>
            ¿Olvidaste tu contraseña?
          </button>
        )}

        {message && <p className="intro-msg">{message}</p>}

        {recoverMode ? (
          <>
            <button
              type="button"
              className="intro-btn intro-btn--login"
              onClick={handleRecoverPassword}
              disabled={loading}
            >
              {loading ? "Enviando..." : "Enviar enlace de recuperación"}
            </button>
            <button type="button" className="intro-link intro-link--block" onClick={backToLogin}>
              Volver al inicio de sesión
            </button>
          </>
        ) : (
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
        )}

      </div>
    </section>
  );
}
