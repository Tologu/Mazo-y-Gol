/**
 * ESTE ARCHIVO SOLO VIVE EN EL BACKEND / CONFIGURACIÓN INTERNA
 * Sirve para mapear los datos de la API real con los nombres ficticios de la App.
 * El usuario final NUNCA debe ver las claves (nombres reales de LaLiga).
 */

export type EquipoFicticio = {
  tag: string;
  nombreWeb: string;
  colorPrimario: string;
  colorSecundario: string;
};

/** Clave = nombre oficial LaLiga / RFEF (uso interno, nunca en UI). */
export const MAPEO_EQUIPOS = {
  "Deportivo Alavés": {
    tag: "ALV",
    nombreWeb: "Vitoria Albiazul",
    colorPrimario: "Azul",
    colorSecundario: "Blanco",
  },
  "Athletic Club": {
    tag: "BIL",
    nombreWeb: "Bilbao Rojiblanco",
    colorPrimario: "Rojo",
    colorSecundario: "Blanco",
  },
  "Atlético de Madrid": {
    tag: "MAD",
    nombreWeb: "Madrid Rayado",
    colorPrimario: "Rojo",
    colorSecundario: "Blanco",
  },
  "F. C. Barcelona": {
    tag: "BCN",
    nombreWeb: "Barcelona Azulgrana",
    colorPrimario: "Azul",
    colorSecundario: "Rojo",
  },
  "R. C. Celta de Vigo": {
    tag: "CEL",
    nombreWeb: "Vigo Celeste",
    colorPrimario: "Cian",
    colorSecundario: "Blanco",
  },
  "Deportivo de A Coruña": {
    tag: "DEP",
    nombreWeb: "La Coruña Blanquiazul",
    colorPrimario: "Azul",
    colorSecundario: "Blanco",
  },
  "Elche C. F.": {
    tag: "ELC",
    nombreWeb: "Elche Franjiverde",
    colorPrimario: "Verde",
    colorSecundario: "Blanco",
  },
  "R. C. D. Espanyol": {
    tag: "ESP",
    nombreWeb: "Cornellá Periquito",
    colorPrimario: "Azul",
    colorSecundario: "Blanco",
  },
  "Getafe C. F.": {
    tag: "GET",
    nombreWeb: "Getafe Azulón",
    colorPrimario: "Azul",
    colorSecundario: "Blanco",
  },
  "Levante U. D.": {
    tag: "LEV",
    nombreWeb: "Valencia Granota",
    colorPrimario: "Azul",
    colorSecundario: "Magenta",
  },
  "Málaga C. F.": {
    tag: "MGA",
    nombreWeb: "Málaga Boquerón",
    colorPrimario: "Cian",
    colorSecundario: "Blanco",
  },
  "C. A. Osasuna": {
    tag: "OSA",
    nombreWeb: "Pamplona Rojillo",
    colorPrimario: "Rojo",
    colorSecundario: "Azul",
  },
  "Racing de Santander": {
    tag: "RAC",
    nombreWeb: "Santander Verdiblanco",
    colorPrimario: "Verde",
    colorSecundario: "Blanco",
  },
  "Rayo Vallecano": {
    tag: "RVA",
    nombreWeb: "Vallecas Franjirrojo",
    colorPrimario: "Rojo",
    colorSecundario: "Blanco",
  },
  "Real Betis Balompié": {
    tag: "BET",
    nombreWeb: "Sevilla Verdiblanco",
    colorPrimario: "Verde",
    colorSecundario: "Blanco",
  },
  "Real Madrid C. F.": {
    tag: "MDB",
    nombreWeb: "Madrid Blanco",
    colorPrimario: "Blanco",
    colorSecundario: "Amarillo",
  },
  "Real Sociedad": {
    tag: "RSO",
    nombreWeb: "San Sebastián Txuri",
    colorPrimario: "Azul",
    colorSecundario: "Blanco",
  },
  "Sevilla F. C.": {
    tag: "SEV",
    nombreWeb: "Sevilla Nervión",
    colorPrimario: "Rojo",
    colorSecundario: "Blanco",
  },
  "Valencia C. F.": {
    tag: "VAL",
    nombreWeb: "Valencia Ché",
    colorPrimario: "Blanco",
    colorSecundario: "Negro",
  },
  "Villarreal C. F.": {
    tag: "VIL",
    nombreWeb: "Villarreal Amarillo",
    colorPrimario: "Amarillo",
    colorSecundario: "Azul",
  },
} as const satisfies Record<string, EquipoFicticio>;

export type NombreEquipoReal = keyof typeof MAPEO_EQUIPOS;

/**
 * Variantes que devuelve LaLiga.com, RFEF o APIs externas → clave canónica de MAPEO_EQUIPOS.
 */
export const ALIAS_NOMBRES_API: Record<string, NombreEquipoReal> = {
  "Deportivo Alavés": "Deportivo Alavés",
  "Alavés": "Deportivo Alavés",
  "Athletic Club": "Athletic Club",
  "Athletic": "Athletic Club",
  "Atlético de Madrid": "Atlético de Madrid",
  "Club Atlético de Madrid": "Atlético de Madrid",
  "Atletico de Madrid": "Atlético de Madrid",
  "F. C. Barcelona": "F. C. Barcelona",
  "FC Barcelona": "F. C. Barcelona",
  "Barcelona": "F. C. Barcelona",
  "R. C. Celta de Vigo": "R. C. Celta de Vigo",
  "RC Celta de Vigo": "R. C. Celta de Vigo",
  "Celta de Vigo": "R. C. Celta de Vigo",
  "Celta": "R. C. Celta de Vigo",
  "Deportivo de A Coruña": "Deportivo de A Coruña",
  "RC Deportivo": "Deportivo de A Coruña",
  "Deportivo": "Deportivo de A Coruña",
  "Elche C. F.": "Elche C. F.",
  "Elche CF": "Elche C. F.",
  "Elche": "Elche C. F.",
  "R. C. D. Espanyol": "R. C. D. Espanyol",
  "RCD Espanyol": "R. C. D. Espanyol",
  "Espanyol": "R. C. D. Espanyol",
  "Getafe C. F.": "Getafe C. F.",
  "Getafe CF": "Getafe C. F.",
  "Getafe": "Getafe C. F.",
  "Levante U. D.": "Levante U. D.",
  "Levante UD": "Levante U. D.",
  "Levante": "Levante U. D.",
  "Málaga C. F.": "Málaga C. F.",
  "Málaga CF": "Málaga C. F.",
  "Malaga CF": "Málaga C. F.",
  "Málaga": "Málaga C. F.",
  "C. A. Osasuna": "C. A. Osasuna",
  "Club Atlético Osasuna": "C. A. Osasuna",
  "Osasuna": "C. A. Osasuna",
  "Racing de Santander": "Racing de Santander",
  "Real Racing Club de Santander": "Racing de Santander",
  "Racing": "Racing de Santander",
  "Rayo Vallecano": "Rayo Vallecano",
  "Rayo Vallecano de Madrid": "Rayo Vallecano",
  "Rayo": "Rayo Vallecano",
  "Real Betis Balompié": "Real Betis Balompié",
  "Real Betis": "Real Betis Balompié",
  "Betis": "Real Betis Balompié",
  "Real Madrid C. F.": "Real Madrid C. F.",
  "Real Madrid CF": "Real Madrid C. F.",
  "Real Madrid": "Real Madrid C. F.",
  "Real Sociedad": "Real Sociedad",
  "Real Sociedad de Fútbol": "Real Sociedad",
  "Sevilla F. C.": "Sevilla F. C.",
  "Sevilla FC": "Sevilla F. C.",
  "Sevilla": "Sevilla F. C.",
  "Valencia C. F.": "Valencia C. F.",
  "Valencia CF": "Valencia C. F.",
  "Valencia": "Valencia C. F.",
  "Villarreal C. F.": "Villarreal C. F.",
  "Villarreal CF": "Villarreal C. F.",
  "Villarreal": "Villarreal C. F.",
};

/** Normaliza texto (minúsculas, sin acentos extra) para búsqueda flexible. */
function normalizar(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLowerCase()
    .trim();
}

/**
 * Resuelve un nombre recibido de la API real → datos ficticios para BD/UI.
 * Devuelve null si no se reconoce el equipo.
 */
export function resolverEquipoDesdeApi(nombreApi: string): EquipoFicticio | null {
  const canonico =
    ALIAS_NOMBRES_API[nombreApi.trim()] ??
    ALIAS_NOMBRES_API[
      Object.keys(ALIAS_NOMBRES_API).find(
        (k) => normalizar(k) === normalizar(nombreApi),
      ) ?? ""
    ];

  if (!canonico) return null;
  return MAPEO_EQUIPOS[canonico];
}

/** Nombre ficticio listo para guardar en Supabase o mostrar en UI. */
export function aNombreWeb(nombreApi: string): string | null {
  return resolverEquipoDesdeApi(nombreApi)?.nombreWeb ?? null;
}

/** Tag corto (ALV, BCN…) para badges internos. */
export function aTag(nombreApi: string): string | null {
  return resolverEquipoDesdeApi(nombreApi)?.tag ?? null;
}

/** Lista de todos los nombres web ficticios (única salida permitida al cliente). */
export function listarNombresWeb(): string[] {
  return Object.values(MAPEO_EQUIPOS).map((e) => e.nombreWeb);
}

/** Transforma un partido crudo de API → formato interno de la app. */
export type PartidoApiExterno = {
  local: string;
  visitante: string;
  fechaInicio: string;
  jornada?: number;
};

export type PartidoApp = {
  local: EquipoFicticio;
  visitante: EquipoFicticio;
  fechaInicio: string;
  jornada?: number;
};

export function transformarPartidoApi(partido: PartidoApiExterno): PartidoApp {
  const local = resolverEquipoDesdeApi(partido.local);
  const visitante = resolverEquipoDesdeApi(partido.visitante);

  if (!local || !visitante) {
    throw new Error(
      `Equipo no mapeado: local="${partido.local}" visitante="${partido.visitante}"`,
    );
  }

  return {
    local,
    visitante,
    fechaInicio: partido.fechaInicio,
    jornada: partido.jornada,
  };
}
