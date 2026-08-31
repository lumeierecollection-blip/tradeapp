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
  // Rule: Reject stale or insufficient data
  if (m.dataQuality === 'STALE_DATA' || m.dataQuality === 'INSUFFICIENT_DATA') {
    return null;
  }

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
  const entry = m.price;

  // Dynamic Stop-Loss (ATR and swing structure aware)
  const atrVal = (m.atrPct > 0 ? m.atrPct : 1.0) * entry / 100;
  let stopLoss;
  if (bias === 'buy') {
    const structuralStop = m.support > 0 && m.support < entry ? m.support * 0.995 : entry - atrVal * 1.5;
    stopLoss = Math.min(entry - atrVal * 1.0, structuralStop);
    if (stopLoss >= entry) stopLoss = entry * 0.98;
  } else {
    const structuralStop = m.resistance > 0 && m.resistance > entry ? m.resistance * 1.005 : entry + atrVal * 1.5;
    stopLoss = Math.max(entry + atrVal * 1.0, structuralStop);
    if (stopLoss <= entry) stopLoss = entry * 1.02;
  }

  // Dynamic Take-Profit (Market structure resistance/support & volatility projection, fully dynamic and unconstrained)
  let takeProfit;
  if (bias === 'buy') {
    const structuralDistance = m.resistance > entry ? m.resistance - entry : atrVal * 4.0;
    const projectedMove = Math.max(atrVal * 2.5, structuralDistance * 0.92);
    takeProfit = entry + projectedMove;
    if (takeProfit <= entry) takeProfit = entry * 1.05;
  } else {
    const structuralDistance = m.support < entry ? entry - m.support : atrVal * 4.0;
    const projectedMove = Math.max(atrVal * 2.5, structuralDistance * 0.92);
    takeProfit = entry - projectedMove;
    if (takeProfit >= entry) takeProfit = entry * 0.95;
  }

  const risk = Math.abs(entry - stopLoss);
  const reward = Math.abs(takeProfit - entry);
  const riskReward = risk > 0 ? reward / risk : 0;
  const riskPercent = (risk / entry) * 100;
  const rewardPercent = (reward / entry) * 100;
  const expectedMove = rewardPercent;

  // Setup Tiers classification based on quality
  const multiTfAgreement = (bias === 'buy' ? (m.change5m > 0 && m.change15m > 0 && m.change1h > 0) : (m.change5m < 0 && m.change15m < 0 && m.change1h < 0));
  let setupTier = 'normal';
  if (multiTfAgreement && m.volumeRatio >= 1.4 && probability >= 80 && riskReward >= 2.0) {
    setupTier = 'very_strong';
  } else if ((multiTfAgreement || m.volumeRatio >= 1.2) && probability >= 68 && riskReward >= 1.5) {
    setupTier = 'strong';
  } else if (probability >= 50) {
    setupTier = 'normal';
  } else {
    setupTier = 'weak';
  }

  // Structured Explanations
  const targetReason = `Target is set at ${takeProfit.toFixed(2)} (${rewardPercent.toFixed(1)}% move), derived from current volatility (ATR ${(m.atrPct || 0).toFixed(2)}%) and structural ${bias === 'buy' ? 'resistance' : 'support'} levels.`;
  const stopReason = `Stop loss is set at ${stopLoss.toFixed(2)} (${riskPercent.toFixed(1)}% risk), positioned beyond recent swing structure to protect against market noise.`;
  const tierReason = `Setup classified as ${setupTier.toUpperCase()} based on multi-timeframe momentum (${multiTfAgreement ? 'aligned' : 'mixed'}), volume confirmation (${m.volumeRatio.toFixed(1)}x), and R:R ratio (1:${riskReward.toFixed(1)}).`;

  const reasons = [
    {
      category: 'Momentum',
      title: 'Multi-timeframe momentum',
      status: multiTfAgreement ? 'positive' : 'neutral',
      value: `${fmtPct(m.change1h)} (1h)`,
      explanation: `1h momentum is ${m.change1h >= 0 ? 'bullish' : 'bearish'} with 5m/15m alignment.`
    },
    {
      category: 'Volume',
      title: 'Relative volume',
      status: m.volumeRatio >= 1.2 ? 'positive' : 'neutral',
      value: `${m.volumeRatio.toFixed(1)}x`,
      explanation: `Trading volume is ${m.volumeRatio.toFixed(1)}x the baseline.`
    },
    {
      category: 'RSI',
      title: 'RSI indicator',
      status: 'neutral',
      value: `${Math.round(m.rsi14)}`,
      explanation: rsiPlain(m.rsi14, bias)
    }
  ];

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
    setupTier,
    expectedMove,
    riskPercent,
    rewardPercent,
    riskReward,
    dataQuality: m.dataQuality || 'GOOD',
    reasons,
    targetReason,
    stopReason,
    tierReason,
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
  const aligned5 = (bias === 'buy' ? m.change5m : -m.change5m) / 100;
  const aligned15 = (bias === 'buy' ? m.change15m : -m.change15m) / 100;
  const aligned1h = (bias === 'buy' ? m.change1h : -m.change1h) / 100;

  let perMinute = (entry * aligned5) / 5;
  if (perMinute <= 0) perMinute = (entry * aligned15) / 15;
  if (perMinute <= 0) perMinute = (entry * aligned1h) / 60;

  // Volatility floor: how far price tends to travel per minute based on
  // recent 1h candle ranges. Never promise a faster target than the
  // market's own choppiness supports.
  const atrPct = m.atrPct > 0 ? m.atrPct : 0.6;
  const volPerMinute = (entry * atrPct) / 100 / 60;
  if (perMinute <= 0) perMinute = volPerMinute * 0.5;

  let minutes = distance / perMinute;
  const volFloor = distance / volPerMinute;
  if (minutes < volFloor) minutes = volFloor;
  if (minutes > 4 * 60) minutes = 4 * 60;

  // Volume confirms pace: participation makes targets arrive sooner,
  // thin volume means moves stall and take longer.
  if (m.volumeRatio >= 1.2) minutes *= 0.85;
  if (m.volumeRatio < 0.8) minutes *= 1.25;
  if (m.recentVolumeRatio >= 1.3) minutes *= 0.9;

  minutes = clamp(minutes, 25, 12 * 60);
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
