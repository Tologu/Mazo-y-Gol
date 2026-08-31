"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { abrirPronosticosJornadaClient } from "@/lib/jornada-client";

type Props = {
  ligaId: string;
  jornada: number;
};

export function AbrirPronosticosButton({ ligaId, jornada }: Props) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function handleAbrir() {
    setMessage(null);
    const ok = window.confirm(
      `¿Abrir pronósticos de la jornada ${jornada}?\n\nSolo se abre esta jornada. Las anteriores (si estaban cerradas) seguirán cerradas.`,
    );
    if (!ok) return;

    setBusy(true);
    const res = await abrirPronosticosJornadaClient(ligaId, jornada);
    setBusy(false);

    if (!res.ok) {
      setMessage(res.error);
      return;
    }

    setMessage(`Jornada ${jornada}: pronósticos abiertos.`);
    router.refresh();
  }

  return (
    <div className="jornada-open-wrap">
      <button
        type="button"
        className="jornada-open-btn"
        onClick={handleAbrir}
        disabled={busy}
      >
        {busy ? "Abriendo..." : "Abrir pronósticos"}
      </button>
      {message && <p className="jornada-open-msg tve-yellow">{message}</p>}
    </div>
  );
}
