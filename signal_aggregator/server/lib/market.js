const yahooBase = 'https://query1.finance.yahoo.com';

const FOREX_SYMBOLS = ['EURUSD=X', 'GBPUSD=X', 'USDJPY=X', 'GC=F', 'AUDUSD=X'];

export function isForexSymbol(symbol) {
  return FOREX_SYMBOLS.includes(symbol) || symbol.endsWith('=X');
}

async function yahooGet(url) {
  const res = await fetch(url, { signal: AbortSignal.timeout(20_000) });
  if (!res.ok) throw new Error(`Yahoo API ${res.status}: ${await res.text()}`);
  return res.json();
}

export async function fetchSnapshots(symbols) {
  const results = {};
  await Promise.all(
    symbols.map(async (symbol) => {
      try {
        results[symbol] = await fetchSnapshot(symbol);
      } catch {
        // Skip symbols we cannot get data for.
      }
    }),
  );
  return results;
}

export async function fetchSnapshot(symbol) {
  const url = `${yahooBase}/v8/finance/chart/${encodeURIComponent(symbol)}?interval=1h&range=1d`;
  const data = await yahooGet(url);
  const result = data.chart.result?.[0];
  if (!result) throw new Error('No data');

  const meta = result.meta;
  const lastPrice = meta.regularMarketPrice ?? 0;
  const prevClose = meta.chartPreviousClose ?? lastPrice;
  const change24h = prevClose > 0 ? ((lastPrice - prevClose) / prevClose) * 100 : 0;

  const quotes = result.indicators?.quote?.[0] || {};
  const closes = (quotes.close || []).filter((v) => v != null);
  const highs = (quotes.high || []).filter((v) => v != null);
  const lows = (quotes.low || []).filter((v) => v != null);
  const volumes = (quotes.volume || []).filter((v) => v != null);

  const volume24h = volumes.reduce((a, b) => a + b, 0);
  const avgVolume = volumes.length > 0 ? volume24h / volumes.length : 0;

  const change5m = percentChange(closes, closes.length - 4, closes.length - 1);
  const change15m = percentChange(closes, closes.length - 16, closes.length - 1);
  const change1h = percentChange(closes, closes.length - 2, closes.length - 1);

  const rsi14 = rsi(closes, 14);

  const window = highs.length >= 24 ? highs.slice(-24) : highs;
  const lowWindow = lows.length >= 24 ? lows.slice(-24) : lows;
  const support = Math.min(...lowWindow);
  const resistance = Math.max(...window);

  const atrPct = atrOf(highs, lows, lastPrice);

  const recentVolumeRatio =
    volumes.length >= 6 && avgVolume > 0
      ? volumes.slice(-6).reduce((a, b) => a + b, 0) / 6 / avgVolume
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
    source: 'yahoo',
    at: new Date().toISOString(),
  };
}

function atrOf(highs, lows, price) {
  if (highs.length < 15 || price <= 0) return 0;
  let sum = 0;
  for (let i = highs.length - 14; i < highs.length; i++) {
    sum += highs[i] - lows[i];
  }
  return (sum / 14 / price) * 100;
}

function percentChange(arr, from, to) {
  if (!arr || arr.length < 2 || from < 0 || to < 0 || from >= arr.length || to >= arr.length) return 0;
  const first = arr[from];
  const last = arr[to];
  if (!first || first <= 0) return 0;
  return ((last - first) / first) * 100;
}

function rsi(closes, period) {
  if (closes.length < period + 1) return 50;
  let gainSum = 0;
  let lossSum = 0;
  for (let i = 1; i <= period; i++) {
    const change = closes[i] - closes[i - 1];
    if (change >= 0) gainSum += change;
    else lossSum -= change;
  }
  let avgGain = gainSum / period;
  let avgLoss = lossSum / period;
  for (let i = period + 1; i < closes.length; i++) {
    const change = closes[i] - closes[i - 1];
    avgGain = (avgGain * (period - 1) + (change > 0 ? change : 0)) / period;
    avgLoss = (avgLoss * (period - 1) + (change < 0 ? -change : 0)) / period;
  }
  if (avgLoss === 0) return 100;
  const rs = avgGain / avgLoss;
  return 100 - 100 / (1 + rs);
}
