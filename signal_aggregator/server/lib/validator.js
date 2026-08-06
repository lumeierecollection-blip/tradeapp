import { analyzeSentiment } from './sentiment.js';

const DIRECTION_LABEL = { buy: 'BUY', sell: 'SELL', wait: 'WAIT' };

export function validateSignal(signal, markets) {
  for (const symbol of signal.symbols) {
    const market = markets[symbol];
    if (!market) continue;
    const result = validateSymbol(signal, symbol, market);
    if (result) return result;
  }
  return null;
}

function validateSymbol(signal, symbol, market) {
  const m = marketView(market);
  const sentiment = analyzeSentiment(`${signal.title}\n${signal.text}`);
  if (sentiment.direction === 'wait') return null;

  const bias = sentiment.direction;
  const factors = [];

  // 1. Momentum alignment (30%)
  const momentumScore = momentumScoreOf(m, bias);
  factors.push({
    label: 'Momentum',
    score: momentumScore,
    plain: `Price is ${fmtPct(m.change1h)} over the last hour ${
      bias === 'buy' ? '— matches the bullish talk.' : '— matches the bearish talk.'
    }`,
  });

  // 2. Volume confirmation (20%)
  const volumeScore = clamp(((m.volumeRatio - 0.5) / 1.5) * 100 + 40, 5, 100);
  factors.push({
    label: 'Volume',
    score: volumeScore,
    plain: `Trading volume is ${m.volumeRatio.toFixed(1)}x normal. ${
      m.volumeRatio >= 1.2
        ? 'Strong participation backs this move.'
        : 'Quiet volume — the move is less confirmed.'
    }`,
  });

  // 3. RSI position (20%)
  const rsiScore = rsiScoreOf(m.rsi14, bias);
  factors.push({
    label: 'RSI',
    score: rsiScore,
    plain: `RSI is ${Math.round(m.rsi14)} out of 100. ${rsiPlain(m.rsi14, bias)}`,
  });

  // 4. Support / resistance (20%)
  const srScore = supportResistanceScore(m, bias);
  factors.push({
    label: 'Entry zone',
    score: srScore,
    plain:
      bias === 'buy'
        ? `Price sits ${fmtPct(m.distanceToSupport)} above recent support — ${
            m.nearSupport ? 'a good entry area.' : 'not an ideal entry yet.'
          }`
        : `Price sits ${fmtPct(m.distanceToResistance)} below recent resistance — ${
            m.nearResistance ? 'a good level to expect a pullback.' : 'not an ideal sell area yet.'
          }`,
  });

  // 5. Message clarity (10%)
  const clarityScore = sentiment.confidence * 100;
  factors.push({
    label: 'Message clarity',
    score: clarityScore,
    plain: `The post gives a ${
      bias === 'buy' ? 'clear bullish' : 'clear bearish'
    } signal${sentiment.trigger ? ` ("${sentiment.trigger}")` : ''} .`,
  });

  const probability = clamp(weighted(factors) * 100, 5, 95);
  const riskBuffer =
    bias === 'buy'
      ? Math.max(
          m.price * 0.015,
          clamp(m.price - m.support, 0, m.price * 0.05) * 0.5 + m.price * 0.005,
        )
      : Math.max(
          m.price * 0.015,
          clamp(m.resistance - m.price, 0, m.price * 0.05) * 0.5 + m.price * 0.005,
        );

  const entry = m.price;
  const stopLoss = bias === 'buy' ? entry - riskBuffer : entry + riskBuffer;
  const takeProfit = bias === 'buy' ? entry + riskBuffer * 1.5 : entry - riskBuffer * 1.5;

  const validatedAt = signal.validatedAt ? new Date(signal.validatedAt) : new Date();
  const buyAt = nextMinute(validatedAt);
  const sellAt = new Date(buyAt.getTime() + sellOffsetMs(m, bias, entry, takeProfit));

  return {
    signal,
    symbol,
    direction: bias,
    probability,
    factors,
    entry,
    stopLoss,
    takeProfit,
    entryWindow: entryWindow(m, bias),
    buyAt: buyAt.toISOString(),
    sellAt: sellAt.toISOString(),
    summary: summary(signal, symbol, m, bias, probability),
  };
}

function nextMinute(t) {
  const d = new Date(t);
  d.setSeconds(0, 0);
  d.setMinutes(d.getMinutes() + 1);
  return d;
}

function sellOffsetMs(m, bias, entry, target) {
  const distance = Math.abs(target - entry);
  const aligned5 = ((bias === 'buy' ? m.change5m : -m.change5m) / 100);
  const aligned15 = ((bias === 'buy' ? m.change15m : -m.change15m) / 100);
  const aligned1h = ((bias === 'buy' ? m.change1h : -m.change1h) / 100);

  let perMinute = (entry * aligned5) / 5;
  if (perMinute <= 0) perMinute = (entry * aligned15) / 15;
  if (perMinute <= 0) perMinute = (entry * aligned1h) / 60;
  if (perMinute <= 0) perMinute = (entry * 0.003) / 60;

  const minutes = clamp(distance / perMinute, 45, 8 * 60);
  return minutes * 60 * 1000;
}

function weighted(factors) {
  const weights = [0.3, 0.2, 0.2, 0.2, 0.1];
  let total = 0;
  for (let i = 0; i < factors.length && i < weights.length; i++) {
    total += (factors[i].score / 100) * weights[i];
  }
  return total;
}

function momentumScoreOf(m, bias) {
  const aligned = bias === 'buy' ? m.change1h : -m.change1h;
  return clamp(50 + aligned * 10, 5, 100);
}

function rsiScoreOf(rsi, bias) {
  if (bias === 'buy') {
    if (rsi >= 75) return 10;
    if (rsi >= 60) return clamp(100 - (rsi - 60) * 2, 10, 100);
    if (rsi >= 40) return 100;
    return clamp(100 - (40 - rsi) * 1.5, 10, 100);
  } else {
    if (rsi <= 25) return 10;
    if (rsi <= 40) return clamp(100 - (40 - rsi) * 2, 10, 100);
    if (rsi <= 60) return 100;
    return clamp(100 - (rsi - 60) * 1.5, 10, 100);
  }
}

function supportResistanceScore(m, bias) {
  if (bias === 'buy') {
    if (m.nearSupport) return 90;
    if (m.nearResistance) return 30;
    return 65;
  } else {
    if (m.nearResistance) return 90;
    if (m.nearSupport) return 30;
    return 65;
  }
}

function entryWindow(m, bias) {
  const aligned = bias === 'buy' ? m.change5m : -m.change5m;
  if (aligned > 0.5) return 'window is open now';
  if (aligned > 0) return 'within the next 1\u20132 hours';
  return 'watch for the next 3\u20136 hours';
}

function rsiPlain(rsi, bias) {
  if (bias === 'buy') {
    if (rsi >= 75) return 'It is overbought \u2014 buying now chases a hot price.';
    if (rsi >= 60) return 'Warming up, but still has room before overbought.';
    if (rsi >= 40) return 'A healthy middle zone \u2014 good room to rise.';
    return 'Oversold \u2014 sellers may be exhausted, so a bounce is possible.';
  } else {
    if (rsi <= 25) return 'Oversold \u2014 falling further is possible but a bounce is near.';
    if (rsi <= 40) return 'Weakening \u2014 room to fall further.';
    if (rsi <= 60) return 'A middle zone \u2014 fine for a short-term pullback.';
    return 'Overbought \u2014 buyers may be running out of steam.';
  }
}

function summary(signal, symbol, m, bias, prob) {
  const source = signal.sourceName;
  if (bias === 'buy') {
    return (
      `A post on ${source} talks about ${symbol} in a positive way. The market ` +
      `currently agrees: momentum is ${m.change1h >= 0 ? 'up' : 'mixed'} ` +
      `(${fmtPct(m.change1h)} in the last hour), volume is ` +
      `${m.volumeRatio.toFixed(1)}x normal, and RSI (${Math.round(m.rsi14)}) ` +
      `is not overbought. Estimated chance this works out: ${Math.round(prob)}%.`
    );
  }
  return (
    `A post on ${source} talks about ${symbol} negatively. The market ` +
    `currently agrees: momentum is ${m.change1h < 0 ? 'down' : 'mixed'} ` +
    `(${fmtPct(m.change1h)} in the last hour), and RSI (${Math.round(m.rsi14)}) ` +
    `leaves room for a pullback. Estimated chance this works out: ${Math.round(prob)}%.`
  );
}

function marketView(m) {
  const volumeRatio = m.avgVolume <= 0 ? 1 : m.volume24h / m.avgVolume;
  const distanceToSupport = m.support <= 0 ? 1 : (m.price - m.support) / m.price;
  const distanceToResistance = m.resistance <= 0 ? 1 : (m.resistance - m.price) / m.price;
  return {
    ...m,
    volumeRatio,
    distanceToSupport,
    distanceToResistance,
    nearSupport: distanceToSupport < 0.02,
    nearResistance: distanceToResistance < 0.02,
  };
}

export function directionLabel(direction) {
  return DIRECTION_LABEL[direction] || 'WAIT';
}

function fmtPct(v) {
  return `${v.toFixed(1)}%`;
}

function clamp(v, min, max) {
  return Math.min(Math.max(v, min), max);
}
