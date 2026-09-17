export type TipoAcierto = "exacto" | "signo" | "fallo";

export type ResultadoPuntos = {
  tipo: TipoAcierto;
  puntos: number;
};

export function signo1x2(local: number, visitante: number): "1" | "X" | "2" {
  if (local > visitante) return "1";
  if (local < visitante) return "2";
  return "X";
}

export function puntuarPronostico(
  pronLocal: number,
  pronVisitante: number,
  realLocal: number,
  realVisitante: number,
): ResultadoPuntos {
  if (pronLocal === realLocal && pronVisitante === realVisitante) {
    return { tipo: "exacto", puntos: 5 };
  }
  if (
    signo1x2(pronLocal, pronVisitante) === signo1x2(realLocal, realVisitante)
  ) {
    return { tipo: "signo", puntos: 2 };
  }
  return { tipo: "fallo", puntos: 0 };
}
