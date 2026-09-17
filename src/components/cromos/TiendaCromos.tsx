"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { CromoCarta } from "@/components/cromos/CromoCarta";
import { comprarCromoClient } from "@/lib/cromos-client";
import type { CromoMazo } from "@/lib/types";

type Props = {
  ligaId: string;
  saldo: number;
  tienda: CromoMazo[];
};

export function TiendaCromos({ ligaId, saldo, tienda }: Props) {
  const router = useRouter();
  const [savingId, setSavingId] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  async function comprar(cromo: CromoMazo) {
    setMessage(null);
    setSavingId(cromo.cromo_id);
    const result = await comprarCromoClient(cromo.cromo_id, ligaId);
    setSavingId(null);

    if (!result.ok) {
      setMessage(result.error);
      return;
    }

    setMessage(`${cromo.nombre} comprado por ${cromo.precio} monedas.`);
    router.refresh();
  }

  const ocupado = savingId !== null;

  return (
    <div className="tve-tienda">
      <p className="tve-tienda-sub tve-cyan">
        3 cartas para ti · cambia a las 00:00
      </p>
      {message && <p className="intro-msg">{message}</p>}
      {tienda.length === 0 ? (
        <p className="tve-empty tve-yellow">Hoy no hay cartas en la tienda.</p>
      ) : (
        <div className="tve-tienda-grid">
          {tienda.map((cromo) => {
            const puedePagar = saldo >= cromo.precio;
            const comprando = savingId === cromo.cromo_id;
            return (
              <article className="tve-tienda-slot" key={cromo.cromo_id}>
                <div className="tve-tienda-marco">
                  <CromoCarta
                    codigo={cromo.codigo}
                    nombre={cromo.nombre}
                    tipo={cromo.tipo}
                    relleno
                  />
                </div>
                <button
                  type="button"
                  className="sim-btn-save tve-tienda-btn"
                  onClick={() => comprar(cromo)}
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
          })}
        </div>
      )}
    </div>
  );
}
