import { toPair } from './pairs.js';

const BASE = process.env.BINANCE_BASE_URL || 'https://api.binance.com';

async function get(path, query) {
  const url = new URL(`${BASE}${path}`);
  for (const [k, v] of Object.entries(query)) url.searchParams.set(k, String(v));
  const res = await fetch(url, { signal: AbortSignal.timeout(20_000) });
  if (!res.ok) {
    throw new Error(`Market API ${res.status}: ${await res.text()}`);
  }
  return res.json();
}

export async function fetchSnapshots(symbols) {
  const results = {};
  await Promise.all(
    symbols.map(async (symbol) => {
      const pair = toPair(symbol);
      if (!pair) return;
      try {
        results[symbol] = await fetchSnapshot(symbol, pair);
      } catch {
        // Skip coins we cannot get data for.
      }
    }),
  );
  return results;
}

export async function fetchSnapshot(symbol, pair) {
  const ticker = await get('/api/v3/ticker/24hr', { symbol: pair });
  const lastPrice = parseFloat(ticker.lastPrice);
  const change24h = parseFloat(ticker.priceChangePercent);
  const volume24h = parseFloat(ticker.volume);

  const candles5m = await fetchKlines(pair, '5m', 3);
  const change5m = percentChange(candles5m);
  const candles15m = await fetchKlines(pair, '15m', 3);
  const change15m = percentChange(candles15m);

  const candles1h = await fetchKlines(pair, '1h', 96);
  const change1h = percentChange(candles1h);
  const rsi14 = rsi(candles1h, 14);

  const window = candles1h.length >= 24 ? candles1h.slice(candles1h.length - 24) : candles1h;
  const highs = window.map((c) => c.high);
  const lows = window.map((c) => c.low);
  const support = Math.min(...lows);
  const resistance = Math.max(...highs);

  const avgVolume =
    candles1h.length === 0
      ? 1
      : candles1h.reduce((a, c) => a + c.volume, 0) / candles1h.length;

  const atrPct = atrOf(candles1h, lastPrice);
  const recentVolumeRatio =
    candles1h.length >= 6 && avgVolume > 0
      ? candles1h
          .slice(candles1h.length - 6)
          .reduce((a, c) => a + c.volume, 0) /
        6 /
        avgVolume
      : 1.0;

  return {
    symbol,
    price: lastPrice,
    change5m,
    change15m,
    change1h,
    change24h,
    rsi14,
    volume24h,
    avgVolume,
    support,
    resistance,
    atrPct,
    recentVolumeRatio,
    at: new Date().toISOString(),
  };
}

function atrOf(candles, price) {
  if (candles.length < 15 || price <= 0) return 0;
  let sum = 0;
  for (let i = candles.length - 14; i < candles.length; i++) {
    sum += candles[i].high - candles[i].low;
  }
  return (sum / 14 / price) * 100;
}

async function fetchKlines(pair, interval, limit) {
  const data = await get('/api/v3/klines', { symbol: pair, interval, limit });
  if (!Array.isArray(data)) return [];
  return data.map((row) => ({
    openTime: Number(row[0]),
    high: parseFloat(row[2]),
    low: parseFloat(row[3]),
    close: parseFloat(row[4]),
    volume: parseFloat(row[5]),
  }));
}

function percentChange(candles) {
  if (candles.length < 2) return 0;
  const first = candles[0];
  const last = candles[candles.length - 1];
  if (first.close <= 0) return 0;
  return ((last.close - first.close) / first.close) * 100;
}

function rsi(candles, period) {
  if (candles.length < period + 1) return 50;
  let gainSum = 0;
  let lossSum = 0;
  for (let i = 1; i <= period; i++) {
    const change = candles[i].close - candles[i - 1].close;
    if (change >= 0) {
      gainSum += change;
    } else {
      lossSum -= change;
    }
  }
  let avgGain = gainSum / period;
  let avgLoss = lossSum / period;
  for (let i = period + 1; i < candles.length; i++) {
    const change = candles[i].close - candles[i - 1].close;
    avgGain = (avgGain * (period - 1) + (change > 0 ? change : 0)) / period;
    avgLoss = (avgLoss * (period - 1) + (change < 0 ? -change : 0)) / period;
  }
  if (avgLoss === 0) return 100;
  const rs = avgGain / avgLoss;
  return 100 - 100 / (1 + rs);
}
