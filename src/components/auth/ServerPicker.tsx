"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { setLigaActivaClient } from "@/lib/servers-client";
import type { ServidorResumen } from "@/lib/types";

type Props = {
  servidores: ServidorResumen[];
};

export function ServerPicker({ servidores }: Props) {
  const router = useRouter();
  const [loadingId, setLoadingId] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  async function enterServer(ligaId: string, slug: string) {
    setMessage(null);
    setLoadingId(ligaId);
    const result = await setLigaActivaClient(ligaId);
    setLoadingId(null);

    if (!result.ok) {
      setMessage(result.error);
      return;
    }

    router.push(`/s/${result.slug || slug}/clasificacion`);
    router.refresh();
  }

  return (
    <section className="intro-panel">
      <div className="tve-colhead">
        <span>Mis servidores</span>
        <span>P003</span>
      </div>

      <div className="intro-form">
        {servidores.length === 0 ? (
          <p className="intro-note tve-yellow">
            No tienes servidores. Crea uno o únete con un código.
          </p>
        ) : (
          <ul className="tve-list tve-list--matches tve-list--servers">
            {servidores.map((s, i) => {
              const tone = i % 2 === 0 ? "tve-row--white" : "tve-row--cyan";
              return (
                <li key={s.liga_id} className={`tve-row tve-row--server ${tone}`}>
                  <button
                    type="button"
                    className="tve-server-pick"
                    disabled={loadingId === s.liga_id}
                    onClick={() => enterServer(s.liga_id, s.slug)}
                  >
                    <span className="tve-rank-name">{s.nombre}</span>
                    <span className="tve-rank-sub">
                      {s.es_activa ? "activo · " : ""}
                      {s.es_owner ? "owner" : "miembro"}
                      {s.codigo_invite ? ` · ${s.codigo_invite}` : ""}
                      {loadingId === s.liga_id ? " · ..." : " · →"}
                    </span>
                  </button>
                </li>
              );
            })}
          </ul>
        )}
        {message && <p className="intro-msg">{message}</p>}
      </div>
    </section>
  );
}
