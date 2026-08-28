"use client";

import { useRouter } from "next/navigation";

type Props = {
  slug: string;
  basePath: "jornada" | "clasificacion";
  jornada: number;
  totalJornadas?: number;
};

export function JornadaSelector({
  slug,
  basePath,
  jornada,
  totalJornadas = 38,
}: Props) {
  const router = useRouter();

  function irA(n: number) {
    const clamped = Math.min(totalJornadas, Math.max(1, n));
    router.push(`/s/${slug}/${basePath}?jornada=${clamped}`);
  }

  const anterior = jornada <= 1;
  const posterior = jornada >= totalJornadas;

  return (
    <div className="sim-jornada-bar">
      <button
        type="button"
        className="sim-jornada-arrow"
        onClick={() => irA(jornada - 1)}
        disabled={anterior}
        aria-label="Jornada anterior"
      >
        ◄
      </button>
      <select
        className="sim-select-jornada"
        value={jornada}
        aria-label="Seleccionar jornada"
        onChange={(e) => irA(Number.parseInt(e.target.value, 10))}
      >
        {Array.from({ length: totalJornadas }, (_, i) => i + 1).map((n) => (
          <option key={n} value={n}>
            Jornada {n}
          </option>
        ))}
      </select>
      <button
        type="button"
        className="sim-jornada-arrow"
        onClick={() => irA(jornada + 1)}
        disabled={posterior}
        aria-label="Jornada posterior"
      >
        ►
      </button>
    </div>
  );
}
