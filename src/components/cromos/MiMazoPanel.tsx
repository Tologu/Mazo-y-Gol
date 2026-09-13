"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { ManoCromos } from "@/components/cromos/ManoCromos";
import { comprarCromoClient, usarCromoClient } from "@/lib/cromos-client";
import type {
  CromoMazo,
  FilaClasificacion,
  PartidoCalendario,
} from "@/lib/types";

type Props = {
  ligaId: string;
  saldo: number;
  mazo: CromoMazo[];
  partidos: PartidoCalendario[];
  filas: FilaClasificacion[];
  userId: string;
};

/** Un partido admite cromos mientras no tenga resultado y no esté bloqueado. */
function admiteCromos(partido: PartidoCalendario): boolean {
  const tieneResultado =
    partido.goles_local !== null && partido.goles_visitante !== null;
  if (tieneResultado) return false;
  if (partido.partido_estado === "finalizado") return false;
  if (partido.partido_estado === "suspendido") return true;
  return !partido.bloqueado;
}

export function MiMazoPanel({
  ligaId,
  saldo,
  mazo,
  partidos,
  filas,
  userId,
}: Props) {
  const router = useRouter();
  const [activoId, setActivoId] = useState<string | null>(null);
  const [partidoId, setPartidoId] = useState("");
  const [objetivoId, setObjetivoId] = useState("");
  const [savingId, setSavingId] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const enMano = useMemo(
    () => mazo.filter((cromo) => cromo.cantidad > 0),
    [mazo],
  );
  const sinStock = useMemo(
    () => mazo.filter((cromo) => cromo.cantidad < 1),
    [mazo],
  );

  const activeIndex = Math.max(
    0,
    enMano.findIndex((cromo) => cromo.cromo_id === activoId),
  );
  const activo = enMano[activeIndex] ?? null;

  const jugables = partidos.filter(admiteCromos);

  const miPosicion = filas.find((fila) => fila.user_id === userId)?.posicion;
  const objetivos = filas.filter(
    (fila) =>
      miPosicion !== undefined &&
      fila.posicion < miPosicion &&
      miPosicion - fila.posicion <= 3,
  );

  useEffect(() => {
    if (enMano.length === 0) {
      setActivoId(null);
      return;
    }
    if (!enMano.some((cromo) => cromo.cromo_id === activoId)) {
      setActivoId(enMano[0].cromo_id);
    }
  }, [enMano, activoId]);

  useEffect(() => {
    setPartidoId("");
    setObjetivoId("");
  }, [partidos, activo?.cromo_id]);

  async function jugar(cromo: CromoMazo) {
    if (!partidoId) {
      setMessage("Elige el partido en el que quieres jugar la carta.");
      return;
    }
    if (cromo.tipo === "ataque" && !objetivoId) {
      setMessage("Elige contra quién lanzas el ataque.");
      return;
    }

    setMessage(null);
    setSavingId(cromo.cromo_id);
    const result = await usarCromoClient(
      cromo.cromo_id,
      partidoId,
      cromo.tipo === "ataque" ? objetivoId : null,
    );
    setSavingId(null);

    if (!result.ok) {
      setMessage(result.error);
      return;
    }

    setPartidoId("");
    setObjetivoId("");
    setMessage(`${cromo.nombre} jugado.`);
    router.refresh();
  }

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

  if (mazo.length === 0) {
    return (
      <p className="tve-empty tve-yellow">
        El catálogo de cromos aún está vacío.
      </p>
    );
  }

  const ocupado = savingId !== null;

  return (
    <>
      <p className="tve-empty tve-cyan">
        Verde = bonificación sobre ti · Rojo = ataque a un rival
      </p>
      {jugables.length === 0 && (
        <p className="tve-empty tve-yellow">
          Ningún partido de esta jornada admite cromos ahora mismo.
        </p>
      )}
      {message && <p className="intro-msg">{message}</p>}

      {enMano.length === 0 ? (
        <p className="tve-empty tve-yellow">
          No te queda ninguna carta. Cómprala abajo para poder jugarla.
        </p>
      ) : (
        <>
          <ManoCromos
            cromos={enMano}
            activeIndex={activeIndex}
            onChange={(index) => {
              setMessage(null);
              setActivoId(enMano[index]?.cromo_id ?? null);
            }}
          />

          {activo && (
            <div className="tve-cromo-body tve-cromo-acciones">
              <p className="tve-cromo-desc">{activo.descripcion}</p>

              <select
                className="sim-select-jornada"
                value={partidoId}
                aria-label="Partido"
                onChange={(event) => setPartidoId(event.target.value)}
              >
                <option value="">Elige partido...</option>
                {jugables.map((partido) => (
                  <option key={partido.partido_id} value={partido.partido_id}>
                    {partido.local} - {partido.visitante}
                  </option>
                ))}
              </select>

              {activo.tipo === "ataque" &&
                (objetivos.length > 0 ? (
                  <select
                    className="sim-select-jornada"
                    value={objetivoId}
                    aria-label="Rival objetivo"
                    onChange={(event) => setObjetivoId(event.target.value)}
                  >
                    <option value="">Elige rival...</option>
                    {objetivos.map((fila) => (
                      <option key={fila.user_id} value={fila.user_id}>
                        {fila.posicion}. {fila.nombre}
                      </option>
                    ))}
                  </select>
                ) : (
                  <p className="tve-empty tve-yellow">
                    No hay rivales a tu alcance: solo puedes atacar hasta 3
                    puestos por encima de ti.
                  </p>
                ))}

              <button
                type="button"
                className="sim-btn-save tve-cromo-btn"
                onClick={() => jugar(activo)}
                disabled={ocupado || jugables.length === 0}
              >
                {savingId === activo.cromo_id ? "Jugando..." : "Jugar carta"}
              </button>

              <button
                type="button"
                className="sim-btn-suspend tve-cromo-btn"
                onClick={() => comprar(activo)}
                disabled={ocupado || saldo < activo.precio}
              >
                {saldo >= activo.precio
                  ? `Comprar (${activo.precio})`
                  : `Cuesta ${activo.precio}`}
              </button>
            </div>
          )}
        </>
      )}

      {sinStock.length > 0 && (
        <div className="tve-cromo-list">
          <p className="tve-empty tve-yellow">Sin stock · tienda</p>
          {sinStock.map((cromo) => {
            const esAtaque = cromo.tipo === "ataque";
            const puedePagar = saldo >= cromo.precio;
            return (
              <div className="tve-cromo tve-cromo-tienda" key={cromo.cromo_id}>
                <span className={esAtaque ? "tve-red" : "tve-green"}>
                  {esAtaque ? "ATQ" : "BON"}
                </span>
                <span className="tve-cromo-nombre">{cromo.nombre}</span>
                <button
                  type="button"
                  className="sim-btn-suspend"
                  onClick={() => comprar(cromo)}
                  disabled={ocupado || !puedePagar}
                >
                  {puedePagar ? `${cromo.precio}` : `Cuesta ${cromo.precio}`}
                </button>
              </div>
            );
          })}
        </div>
      )}
    </>
  );
}
