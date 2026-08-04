"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { actualizarNombreClient } from "@/lib/perfil-client";

type Props = {
  nombreActual: string;
  username: string;
  email: string;
};

export function MiUsuarioPanel({ nombreActual, username, email }: Props) {
  const router = useRouter();
  const [nombre, setNombre] = useState(nombreActual);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function handleGuardar() {
    setMessage(null);
    setBusy(true);
    const res = await actualizarNombreClient(nombre);
    setBusy(false);

    if (!res.ok) {
      setMessage(res.error);
      return;
    }

    setMessage("Nombre actualizado. Así saldrás en la clasificación.");
    router.refresh();
  }

  return (
    <section className="tve-section">
      <div className="tve-colhead">
        <span>Mi Usuario</span>
        <span>P600</span>
      </div>

      <div className="intro-form">
        <label className="intro-field">
          <span className="intro-label tve-green">
            Nombre en clasificación
          </span>
          <input
            type="text"
            value={nombre}
            onChange={(e) => setNombre(e.target.value)}
            placeholder="Ej. SPECIAL ONE"
            minLength={3}
            maxLength={40}
          />
        </label>

        <label className="intro-field">
          <span className="intro-label tve-cyan">Usuario</span>
          <input type="text" value={username} disabled readOnly />
        </label>

        <label className="intro-field">
          <span className="intro-label tve-yellow">Correo</span>
          <input type="email" value={email} disabled readOnly />
        </label>

        {message && <p className="intro-msg">{message}</p>}

        <button
          type="button"
          className="intro-btn intro-btn--login"
          onClick={handleGuardar}
          disabled={busy || nombre.trim() === nombreActual.trim()}
        >
          {busy ? "Guardando..." : "Guardar nombre"}
        </button>
      </div>
    </section>
  );
}
