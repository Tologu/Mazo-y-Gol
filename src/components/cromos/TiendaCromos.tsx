"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { CromoCarta } from "@/components/cromos/CromoCarta";
import { useCromoZoomTap } from "@/components/cromos/useCromoZoomTap";
import { comprarCromoClient } from "@/lib/cromos-client";
import type { CromoMazo } from "@/lib/types";

type Props = {
  ligaId: string;
  saldo: number;
  tienda: CromoMazo[];
};

function TiendaCromoSlot({
  cromo,
  zoomId,
  onZoomChange,
  ocupado,
  puedePagar,
  comprando,
  onComprar,
}: {
  cromo: CromoMazo;
  zoomId: string | null;
  onZoomChange: (id: string | null) => void;
  ocupado: boolean;
  puedePagar: boolean;
  comprando: boolean;
  onComprar: () => void;
}) {
  const zoomed = zoomId === cromo.cromo_id;
  const apagado = zoomId !== null && !zoomed;

  const zoomTap = useCromoZoomTap({
    onTap: () =>
      onZoomChange(zoomId === cromo.cromo_id ? null : cromo.cromo_id),
    onHold: () => onZoomChange(cromo.cromo_id),
  });

  return (
    <article
      className={`tve-tienda-slot${apagado ? " tve-tienda-slot--apagado" : ""}`}
    >
      <button
        type="button"
        className="tve-tienda-marco-btn"
        aria-label={cromo.nombre}
        aria-pressed={zoomed}
        {...zoomTap}
      >
        <CromoCarta
          codigo={cromo.codigo}
          nombre={cromo.nombre}
          tipo={cromo.tipo}
        />
      </button>
      <button
        type="button"
        className="sim-btn-save tve-tienda-btn"
        onClick={onComprar}
        disabled={ocupado || !puedePagar}
      >
        {comprando
          ? "..."
          : puedePagar
            ? `Comprar ${cromo.precio}`
            : `Cuesta ${cromo.precio}`}
      </button>
    </article>
  );
}

export function TiendaCromos({ ligaId, saldo, tienda }: Props) {
  const router = useRouter();
  const [savingId, setSavingId] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [zoomId, setZoomId] = useState<string | null>(null);

  async function comprar(cromo: CromoMazo) {
    setMessage(null);
    setSavingId(cromo.cromo_id);
    const result = await comprarCromoClient(cromo.cromo_id, ligaId);
    setSavingId(null);

    if (!result.ok) {
      setMessage(result.error);
      return;
    }

    setZoomId(null);
    setMessage(`${cromo.nombre} comprado por ${cromo.precio} monedas.`);
    router.refresh();
  }

  const ocupado = savingId !== null;
  const zoomed = tienda.find((cromo) => cromo.cromo_id === zoomId) ?? null;

  return (
    <div className={`tve-tienda${zoomed ? " tve-tienda--flotante" : ""}`}>
      <p className="tve-tienda-sub tve-cyan">
        3 cartas para ti · cambia a las 00:00
      </p>
      {message && <p className="intro-msg">{message}</p>}
      {tienda.length === 0 ? (
        <p className="tve-empty tve-yellow">Hoy no hay cartas en la tienda.</p>
      ) : (
        <>
          {zoomed && (
            <button
              type="button"
              className="tve-tienda-zoom"
              aria-label={`Cerrar ${zoomed.nombre}`}
              aria-pressed
              onClick={() => setZoomId(null)}
              onContextMenu={(event) => event.preventDefault()}
            >
              <CromoCarta
                codigo={zoomed.codigo}
                nombre={zoomed.nombre}
                tipo={zoomed.tipo}
              />
            </button>
          )}
          <div className="tve-tienda-grid">
            {tienda.map((cromo) => (
              <TiendaCromoSlot
                key={cromo.cromo_id}
                cromo={cromo}
                zoomId={zoomId}
                onZoomChange={setZoomId}
                ocupado={ocupado}
                puedePagar={saldo >= cromo.precio}
                comprando={savingId === cromo.cromo_id}
                onComprar={() => comprar(cromo)}
              />
            ))}
          </div>
        </>
      )}
    </div>
  );
}
