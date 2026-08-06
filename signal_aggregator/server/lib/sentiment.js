const BULLISH = {
  buy: 2.0,
  buying: 1.5,
  'buy the dip': 3.0,
  long: 1.5,
  load: 2.0,
  loading: 1.5,
  accumulate: 2.5,
  accumulation: 2.0,
  accumulating: 2.0,
  bull: 2.0,
  bullish: 2.5,
  'bull run': 3.0,
  breakout: 2.0,
  'break out': 2.0,
  'break through': 2.0,
  pump: 2.5,
  moon: 2.0,
  'to the moon': 3.0,
  upside: 2.0,
  green: 1.0,
  'upcoming rally': 2.5,
  rally: 1.5,
  'support holding': 2.0,
  'support held': 2.0,
  'higher high': 2.0,
  'higher low': 1.5,
  bottom: 1.5,
  bounce: 1.5,
  'reversal up': 2.0,
  approval: 2.0,
  partnership: 2.0,
  adoption: 1.5,
  milestone: 1.5,
  'ath incoming': 2.5,
  'new high': 1.5,
  undervalued: 1.5,
  gem: 1.5,
  stack: 1.5,
  'diamond hands': 1.5,
  hodl: 1.0,
  'trend up': 2.0,
  uptrend: 2.0,
};

const BEARISH = {
  sell: 2.0,
  selling: 1.5,
  exit: 1.5,
  'take profit': 2.0,
  tp: 1.0,
  short: 1.5,
  shorting: 1.5,
  bear: 2.0,
  bearish: 2.5,
  'bear market': 3.0,
  dump: 2.5,
  crash: 2.5,
  correction: 1.5,
  downside: 2.0,
  red: 1.0,
  breakdown: 2.0,
  'break down': 2.0,
  'lower low': 2.0,
  'lower high': 1.5,
  rejection: 2.0,
  rejected: 2.0,
  'resistance holding': 2.0,
  'resistance held': 2.0,
  top: 1.5,
  overbought: 2.0,
  bubble: 2.0,
  scam: 2.5,
  'rug pull': 3.0,
  rugpull: 3.0,
  liquidation: 1.5,
  fud: 1.5,
  'down trend': 2.0,
  downtrend: 2.0,
  'pump and dump': 2.5,
  'pump n dump': 2.5,
  outflow: 1.5,
  'sell the news': 2.0,
};

const NEUTRAL = { bullScore: 0, bearScore: 0, direction: 'wait', confidence: 0, trigger: '' };

export function analyzeSentiment(text) {
  const lower = String(text || '').toLowerCase();
  let bull = 0;
  let bear = 0;
  let trigger = '';

  for (const [word, weight] of Object.entries(BULLISH)) {
    if (lower.includes(word)) {
      bull += weight;
      if (!trigger) trigger = word;
    }
  }
  for (const [word, weight] of Object.entries(BEARISH)) {
    if (lower.includes(word)) {
      bear += weight;
      if (!trigger) trigger = word;
    }
  }

  const total = bull + bear;
  if (total < 1.5) return { ...NEUTRAL };

  let direction;
  if (bull > bear * 1.3) {
    direction = 'buy';
  } else if (bear > bull * 1.3) {
    direction = 'sell';
  } else {
    direction = 'wait';
  }

  const dominance = Math.max(bull, bear);
  const confidence = clamp(dominance / total, 0, 1);
  return { bullScore: bull, bearScore: bear, direction, confidence, trigger };
}

function clamp(v, min, max) {
  return Math.min(Math.max(v, min), max);
}
