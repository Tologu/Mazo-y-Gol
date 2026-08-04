export type PartidoCalendario = {
  partido_id: string;
  jornada_numero: number;
  local: string;
  visitante: string;
  fecha_inicio: string;
  goles_local: number | null;
  goles_visitante: number | null;
  partido_estado: string;
  bloqueado: boolean;
};

export type PronosticoPropio = {
  partido_id: string;
  goles_local: number;
  goles_visitante: number;
};

export type FilaClasificacion = {
  posicion: number;
  user_id: string;
  username: string;
  nombre: string;
  puntos: number;
  aciertos: number;
  aciertos_exactos: number;
};

export type FilaEquipo = {
  equipo: string;
  jugados: number;
  ganados: number;
  empatados: number;
  perdidos: number;
  goles_favor: number;
  goles_contra: number;
  puntos: number;
};

export type PronosticoAjeno = {
  partido_id: string;
  local: string;
  visitante: string;
  goles_local: number;
  goles_visitante: number;
};

export type StatsJornada = {
  jornada: number;
  partidos: number;
  jugados: number;
  pendientes: number;
};

export type ServidorResumen = {
  liga_id: string;
  slug: string;
  nombre: string;
  codigo_invite: string | null;
  es_owner: boolean;
  es_activa: boolean;
  joined_at: string;
};

export type ServidorCreado = {
  liga_id: string;
  slug: string;
  codigo_invite: string;
  nombre: string;
};

export type LigaContexto = {
  id: string;
  slug: string;
  nombre: string;
  codigo_invite: string | null;
  es_owner: boolean;
};

export type BotJugador = {
  user_id: string;
  username: string;
  nombre: string;
};
