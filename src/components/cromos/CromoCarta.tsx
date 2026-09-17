"use client";

import { useEffect, useState } from "react";
import { imagenCromo } from "@/lib/cromos-art";
import type { TipoCromo } from "@/lib/types";

type Props = {
  codigo: string;
  nombre: string;
  tipo: TipoCromo;
  cantidad?: number;
  compact?: boolean;
  relleno?: boolean;
};

export function CromoCarta({
  codigo,
  nombre,
  tipo,
  cantidad,
  compact = false,
  relleno = false,
}: Props) {
  const [sinImagen, setSinImagen] = useState(false);
  const esAtaque = tipo === "ataque";
  const src = imagenCromo(codigo);

  useEffect(() => {
    setSinImagen(false);
  }, [codigo, src]);

  const conArte = !sinImagen;

  return (
    <div
      className={`tve-carta ${esAtaque ? "tve-carta--ataque" : "tve-carta--bonus"}${compact ? " tve-carta--compact" : ""}${conArte ? " tve-carta--arte" : ""}${relleno ? " tve-carta--relleno" : ""}`}
    >
      {!sinImagen && (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          key={codigo}
          className="tve-carta-img"
          src={src}
          alt={nombre}
          onError={() => setSinImagen(true)}
        />
      )}
      {sinImagen && (
        <div className="tve-carta-fallback">
          <span className={esAtaque ? "tve-red" : "tve-green"}>
            {esAtaque ? "ATQ" : "BON"}
          </span>
          <span className="tve-carta-fallback-nombre">{nombre}</span>
        </div>
      )}
      {cantidad != null && cantidad > 1 && conArte && (
        <span className="tve-carta-stock" aria-hidden="true">
          ×{cantidad}
        </span>
      )}
      {!conArte && (
        <div className="tve-carta-pie">
          <span className="tve-carta-pie-nombre">{nombre}</span>
          {cantidad != null && <span className="tve-yellow">x{cantidad}</span>}
        </div>
      )}
    </div>
  );
}
