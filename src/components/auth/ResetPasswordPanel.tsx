"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { PasswordToggleIcon } from "@/components/auth/PasswordToggleIcon";

export function ResetPasswordPanel() {
  const router = useRouter();
  const recoveryClient = useRef<SupabaseClient | null>(null);
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [sessionReady, setSessionReady] = useState(false);
  const [checkingSession, setCheckingSession] = useState(true);
  const [message, setMessage] = useState<string | null>(
    "Comprobando enlace de recuperación...",
  );

  useEffect(() => {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if (!url || !key) {
      setMessage("Supabase no configurado.");
      setCheckingSession(false);
      return;
    }

    const supabase = createClient(url, key, {
      auth: {
        flowType: "implicit",
        detectSessionInUrl: true,
        persistSession: true,
      },
    });
    recoveryClient.current = supabase;

    let active = true;
    supabase.auth.getSession().then(({ data, error }) => {
      if (!active) return;

      setCheckingSession(false);
      if (error || !data.session) {
        setMessage(
          "El enlace no es válido o ha caducado. Solicita uno nuevo desde el inicio.",
        );
        return;
      }

      setSessionReady(true);
      setMessage(null);
    });

    return () => {
      active = false;
    };
  }, []);

  async function handleSubmit() {
    setMessage(null);

    if (!sessionReady) {
      setMessage("No hay una sesión de recuperación válida.");
      return;
    }

    if (password.length < 6) {
      setMessage("La contraseña debe tener al menos 6 caracteres.");
      return;
    }
    if (password !== confirmPassword) {
      setMessage("Las contraseñas no coinciden.");
      return;
    }

    const supabase = recoveryClient.current;
    if (!supabase) {
      setMessage("Supabase no configurado.");
      return;
    }

    setLoading(true);
    const { error } = await supabase.auth.updateUser({ password });
    setLoading(false);

    if (error) {
      setMessage(error.message);
      return;
    }

    await supabase.auth.signOut();
    setMessage("Contraseña actualizada. Ya puedes iniciar sesión.");
    router.push("/?msg=contrasena-actualizada");
    router.refresh();
  }

  return (
    <section className="intro-panel">
      <div className="tve-colhead">
        <span>Nueva contraseña</span>
        <span>P002</span>
      </div>

      <p className="intro-note tve-cyan">
        Elige una contraseña nueva para tu cuenta.
      </p>

      <div className="intro-form">
        <label className="intro-field intro-field--password">
          <span className="intro-label tve-red">Contraseña</span>
          <input
            type={showPassword ? "text" : "password"}
            autoComplete="new-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="mínimo 6 caracteres"
            minLength={6}
          disabled={!sessionReady}
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

        <label className="intro-field intro-field--password">
          <span className="intro-label tve-red">Repetir contraseña</span>
          <input
            type={showPassword ? "text" : "password"}
            autoComplete="new-password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            placeholder="repite la contraseña"
            minLength={6}
          disabled={!sessionReady}
          />
        </label>

        {message && <p className="intro-msg">{message}</p>}

        <button
          type="button"
          className="intro-btn intro-btn--login"
          onClick={handleSubmit}
          disabled={loading || checkingSession || !sessionReady}
        >
          {checkingSession
            ? "Comprobando..."
            : loading
              ? "Guardando..."
              : "Guardar contraseña"}
        </button>

        <Link href="/" className="intro-link intro-link--block">
          Volver al inicio
        </Link>
      </div>
    </section>
  );
}
