export const STMET_MAGIC = 0x53544d54; // 'STMT'
export const STMET_VERSION = 1;
export const STMET_CMD_STORE = 0;
export const STMET_CMD_GET = 1;
export const STMET_CMD_SET = 2;
export const STMET_CMD_DATA = 3;
export const PREFS_BYTES = 180;

export const QUANTITY_KEYS = [
  "temp",
  "humidity",
  "pressure",
  "gasOhm",
  "iaq",
  "co2",
] as const;
export type QuantityKey = (typeof QUANTITY_KEYS)[number];

export const BAND_KEYS = [
  "mean",
  "low",
  "high",
  "veryLow",
  "warnLow",
  "warnHigh",
  "veryHigh",
] as const;
export type BandKey = (typeof BAND_KEYS)[number];

export type MeasurementBand = Record<BandKey, number>;
export type MeasurementRangePrefs = Record<QuantityKey, MeasurementBand> & {
  magic: number;
  version: number;
  cmd: number;
};

function band(
  mean: number,
  low: number,
  high: number,
  veryLow: number,
  warnLow: number,
  warnHigh: number,
  veryHigh: number,
): MeasurementBand {
  return { mean, low, high, veryLow, warnLow, warnHigh, veryHigh };
}

export const DEFAULT_PREFS: MeasurementRangePrefs = {
  magic: STMET_MAGIC,
  version: STMET_VERSION,
  cmd: STMET_CMD_STORE,
  temp: band(15, -10, 40, -20, 0, 35, 45),
  humidity: band(55, 20, 90, 10, 30, 80, 95),
  pressure: band(1013, 980, 1040, 960, 990, 1030, 1050),
  gasOhm: band(50_000, 5_000, 1e7, 1_000, 10_000, 5e6, 2e7),
  iaq: band(50, 0, 150, 0, 25, 100, 200),
  co2: band(600, 400, 1500, 350, 500, 1000, 2000),
};

export function estimatedCo2Ppm(iaq: number): number {
  return 400 + iaq * 4;
}

export function clonePrefs(
  src: MeasurementRangePrefs = DEFAULT_PREFS,
): MeasurementRangePrefs {
  return structuredClone(src);
}

function xorHash(bytes: Uint8Array): number {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let h = 0;
  for (let i = 0; i + 4 <= bytes.length - 4; i += 4) {
    h ^= view.getUint32(i, true);
  }
  return h >>> 0;
}

export function encodePrefs(
  prefs: MeasurementRangePrefs,
  cmd: number,
): Uint8Array {
  const buf = new Uint8Array(PREFS_BYTES);
  const view = new DataView(buf.buffer);
  view.setUint32(0, STMET_MAGIC, true);
  view.setUint8(4, STMET_VERSION);
  view.setUint8(5, cmd);
  view.setUint16(6, 0, true);
  let offset = 8;
  for (const q of QUANTITY_KEYS) {
    for (const k of BAND_KEYS) {
      view.setFloat32(offset, prefs[q][k], true);
      offset += 4;
    }
  }
  view.setUint32(PREFS_BYTES - 4, xorHash(buf), true);
  return buf;
}

export function encodeGet(): Uint8Array {
  return encodePrefs(DEFAULT_PREFS, STMET_CMD_GET);
}

export function decodePrefs(bytes: Uint8Array): MeasurementRangePrefs | null {
  if (bytes.byteLength < PREFS_BYTES) return null;
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const magic = view.getUint32(0, true);
  const version = view.getUint8(4);
  if (magic !== STMET_MAGIC || version !== STMET_VERSION) return null;
  const expected = xorHash(bytes.subarray(0, PREFS_BYTES));
  const got = view.getUint32(PREFS_BYTES - 4, true);
  if (expected !== got) return null;
  const prefs = clonePrefs();
  prefs.cmd = view.getUint8(5);
  let offset = 8;
  for (const q of QUANTITY_KEYS) {
    for (const k of BAND_KEYS) {
      prefs[q][k] = view.getFloat32(offset, true);
      offset += 4;
    }
  }
  return prefs;
}
