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

  return (
    <div className="sim-jornada-bar">
      <select
        className="sim-select-jornada"
        value={jornada}
        aria-label="Seleccionar jornada"
        onChange={(e) =>
          router.push(`/s/${slug}/${basePath}?jornada=${e.target.value}`)
        }
      >
        {Array.from({ length: totalJornadas }, (_, i) => i + 1).map((n) => (
          <option key={n} value={n}>
            Jornada {n}
          </option>
        ))}
      </select>
    </div>
  );
}
