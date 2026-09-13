export type PartidoCalendario = {
  partido_id: string;
  jornada_numero: number;
  local: string;
  visitante: string;
  fecha_inicio: string;
  /** Cierre de la jornada anterior. Null = jornada 1 (sin espera). */
  fecha_apertura: string | null;
  goles_local: number | null;
  goles_visitante: number | null;
  partido_estado: string;
  bloqueado: boolean;
  abierta: boolean;
  /** True si el admin abrió esta jornada a mano (sin abrir las anteriores). */
  apertura_forzada?: boolean;
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

/** Traza de un cromo que intervino en la puntuación de un partido. */
export type CromoAplicadoTraza = {
  codigo: string;
  nombre: string;
  tipo: TipoCromo;
  delta: number;
};

export type PronosticoAjeno = {
  partido_id: string;
  local: string;
  visitante: string;
  goles_local: number;
  goles_visitante: number;
  /** Puntos ya escrutados (con cromos). Null si el partido no se ha escrutado. */
  puntos_finales: number | null;
  cromos: CromoAplicadoTraza[];
};

export type StatsJornada = {
  jornada: number;
  partidos: number;
  jugados: number;
  pendientes: number;
};

export type ModoJuego = "clasica" | "mazo_y_gol";

export type ServidorResumen = {
  liga_id: string;
  slug: string;
  nombre: string;
  codigo_invite: string | null;
  es_owner: boolean;
  es_activa: boolean;
  joined_at: string;
  modo_juego: ModoJuego;
};

export type ServidorCreado = {
  liga_id: string;
  slug: string;
  codigo_invite: string;
  nombre: string;
  modo_juego: ModoJuego;
};

export type LigaContexto = {
  id: string;
  slug: string;
  nombre: string;
  codigo_invite: string | null;
  es_owner: boolean;
  modo_juego: ModoJuego;
};

export type BotJugador = {
  user_id: string;
  username: string;
  nombre: string;
};

export type TipoCromo = "bonificacion" | "ataque";

export type RarezaCromo = "comun" | "rara" | "epica" | "legendaria";

/** Config declarativa del efecto; la interpreta el escrutinio en SQL. */
export type EfectoCromo = {
  kind: string;
  factor?: number;
  puntos?: number;
};

/** Fila de `fn_mi_mazo`: catálogo con lo que tiene el usuario en esa liga. */
export type CromoMazo = {
  cromo_id: string;
  codigo: string;
  nombre: string;
  descripcion: string;
  tipo: TipoCromo;
  rareza: RarezaCromo;
  efecto: EfectoCromo;
  precio: number;
  cantidad: number;
};

/** Fila de `fn_mis_movimientos`: historial de monedas en la liga. */
export type MovimientoMonedas = {
  movimiento_id: string;
  tipo: string;
  cantidad: number;
  saldo: number;
  concepto: string;
  created_at: string;
};

/** Fila de `fn_mis_cromos_jornada`: cromos ya jugados de esta jornada. */
export type CromoEnJuego = {
  aplicado_id: string;
  cromo_codigo: string;
  cromo_nombre: string;
  tipo: TipoCromo;
  estado: "activo" | "anulado" | "resuelto" | "reembolsado";
  partido_id: string;
  local: string;
  visitante: string;
  fecha_inicio: string;
  bloqueado: boolean;
  es_emisor: boolean;
  emisor_nombre: string;
  objetivo_nombre: string | null;
};
