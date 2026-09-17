"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { ManoCromos } from "@/components/cromos/ManoCromos";
import { usarCromoClient } from "@/lib/cromos-client";
import { verPronosticosJugadorClient } from "@/lib/pronosticos-client";
import type {
  CromoMazo,
  FilaClasificacion,
  PartidoCalendario,
  PronosticoAjeno,
} from "@/lib/types";

type Props = {
  ligaId: string;
  jornada: number;
  mazo: CromoMazo[];
  partidos: PartidoCalendario[];
  filas: FilaClasificacion[];
  userId: string;
  yaAtacados: string[];
};

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
  jornada,
  mazo,
  partidos,
  filas,
  userId,
  yaAtacados,
}: Props) {
  const router = useRouter();
  const [activoId, setActivoId] = useState<string | null>(null);
  const [partidoId, setPartidoId] = useState("");
  const [objetivoId, setObjetivoId] = useState("");
  const [pronosticosRival, setPronosticosRival] = useState<PronosticoAjeno[]>(
    [],
  );
  const [cargandoRival, setCargandoRival] = useState(false);
  const [errorRival, setErrorRival] = useState<string | null>(null);
  const [savingId, setSavingId] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const enMano = useMemo(
    () => mazo.filter((cromo) => cromo.cantidad > 0),
    [mazo],
  );

  const activeIndex = Math.max(
    0,
    enMano.findIndex((cromo) => cromo.cromo_id === activoId),
  );
  const activo = enMano[activeIndex] ?? null;
  const esAtaque = activo?.tipo === "ataque";

  const jugables = partidos.filter(admiteCromos);

  const rivales = filas.filter((fila) => fila.user_id !== userId);
  const objetivos = rivales.filter(
    (fila) => !yaAtacados.includes(fila.user_id),
  );

  const partidosAtaque = useMemo(() => {
    const porId = new Map(
      pronosticosRival.map((pronostico) => [pronostico.partido_id, pronostico]),
    );
    return jugables
      .filter((partido) => porId.has(partido.partido_id))
      .map((partido) => ({
        partido,
        pronostico: porId.get(partido.partido_id)!,
      }));
  }, [jugables, pronosticosRival]);

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
    setPronosticosRival([]);
    setErrorRival(null);
  }, [partidos, activo?.cromo_id]);

  useEffect(() => {
    setPartidoId("");
    setPronosticosRival([]);
    setErrorRival(null);

    if (!esAtaque || !objetivoId) return;

    let cancelado = false;
    setCargandoRival(true);

    verPronosticosJugadorClient(ligaId, jornada, objetivoId)
      .then((res) => {
        if (cancelado) return;
        if (!res.ok) {
          setErrorRival(res.error);
          return;
        }
        setPronosticosRival(res.data);
      })
      .finally(() => {
        if (!cancelado) setCargandoRival(false);
      });

    return () => {
      cancelado = true;
    };
  }, [esAtaque, objetivoId, ligaId, jornada]);

  async function jugar(cromo: CromoMazo) {
    if (cromo.tipo === "ataque" && !objetivoId) {
      setMessage("Elige primero contra quién lanzas el ataque.");
      return;
    }
    if (!partidoId) {
      setMessage(
        cromo.tipo === "ataque"
          ? "Elige el pronóstico del rival al que aplicas el ataque."
          : "Elige el partido en el que quieres jugar la carta.",
      );
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
    setPronosticosRival([]);
    setMessage(`${cromo.nombre} jugado.`);
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
  const sinPartidoAtaque =
    esAtaque &&
    Boolean(objetivoId) &&
    !cargandoRival &&
    !errorRival &&
    partidosAtaque.length === 0;

  return (
    <>
      <p className="tve-empty tve-cyan">
        Verde = bonificación sobre ti · Rojo = elige rival y luego su
        pronóstico. Cada jugador solo puede recibir un ataque por jornada.
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

              {esAtaque &&
                (objetivos.length > 0 ? (
                  <select
                    className="sim-select-jornada"
                    value={objetivoId}
                    aria-label="Rival objetivo"
                    onChange={(event) => setObjetivoId(event.target.value)}
                  >
                    <option value="">1. Elige rival...</option>
                    {objetivos.map((fila) => (
                      <option key={fila.user_id} value={fila.user_id}>
                        {fila.posicion}. {fila.nombre}
                      </option>
                    ))}
                  </select>
                ) : (
                  <p className="tve-empty tve-yellow">
                    {rivales.length === 0
                      ? "No hay otros jugadores en este servidor."
                      : "Todos los rivales ya han recibido un ataque esta jornada."}
                  </p>
                ))}

              {esAtaque && objetivoId && cargandoRival && (
                <p className="tve-empty tve-cyan">Cargando pronósticos...</p>
              )}

              {esAtaque && errorRival && (
                <p className="tve-empty tve-yellow">{errorRival}</p>
              )}

              {esAtaque && sinPartidoAtaque && (
                <p className="tve-empty tve-yellow">
                  Ese rival no tiene pronósticos abiertos en esta jornada.
                </p>
              )}

              {(!esAtaque || (objetivoId && partidosAtaque.length > 0)) && (
                <select
                  className="sim-select-jornada"
                  value={partidoId}
                  aria-label={esAtaque ? "Pronóstico del rival" : "Partido"}
                  onChange={(event) => setPartidoId(event.target.value)}
                >
                  <option value="">
                    {esAtaque
                      ? "2. Elige su pronóstico..."
                      : "Elige partido..."}
                  </option>
                  {esAtaque
                    ? partidosAtaque.map(({ partido, pronostico }) => (
                        <option
                          key={partido.partido_id}
                          value={partido.partido_id}
                        >
                          {partido.local} {pronostico.goles_local}-
                          {pronostico.goles_visitante} {partido.visitante}
                        </option>
                      ))
                    : jugables.map((partido) => (
                        <option
                          key={partido.partido_id}
                          value={partido.partido_id}
                        >
                          {partido.local} - {partido.visitante}
                        </option>
                      ))}
                </select>
              )}

              <button
                type="button"
                className="sim-btn-save tve-cromo-btn"
                onClick={() => jugar(activo)}
                disabled={
                  ocupado ||
                  jugables.length === 0 ||
                  (esAtaque && (objetivos.length === 0 || !objetivoId))
                }
              >
                {savingId === activo.cromo_id ? "Jugando..." : "Jugar carta"}
              </button>
            </div>
          )}
        </>
      )}
    </>
  );
}
