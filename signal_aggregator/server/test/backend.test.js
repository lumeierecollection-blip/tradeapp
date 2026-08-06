import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

import { analyzeSentiment } from '../lib/sentiment.js';
import { extractSymbols } from '../lib/symbols.js';
import { validateSignal } from '../lib/validator.js';

function makeMarket() {
  return {
    symbol: 'BTC',
    price: 60000,
    change5m: 0.4,
    change15m: 0.9,
    change1h: 2.0,
    change24h: 5.0,
    rsi14: 55,
    volume24h: 1500,
    avgVolume: 1000,
    support: 59000,
    resistance: 62000,
    at: new Date().toISOString(),
  };
}

function makeSignal() {
  return {
    id: 't1',
    sourceKey: 'reddit',
    sourceName: 'r/Bitcoin',
    author: 'u/test',
    title: 'BTC bullish',
    text: 'Buy bitcoin, the market looks strong.',
    symbols: ['BTC'],
    postedAt: new Date().toISOString(),
    url: '',
  };
}

describe('Sentiment', () => {
  it('detects bullish talk', () => {
    const result = analyzeSentiment('BTC looks bullish, buy the dip and accumulate');
    assert.equal(result.direction, 'buy');
    assert.ok(result.confidence > 0.5);
  });

  it('detects bearish talk', () => {
    const result = analyzeSentiment('ETH is overbought, sell before the dump');
    assert.equal(result.direction, 'sell');
  });

  it('neutral when no keywords', () => {
    const result = analyzeSentiment('the weather is nice today');
    assert.equal(result.direction, 'wait');
  });
});

describe('Symbols', () => {
  it('extracts tickers and names', () => {
    const found = extractSymbols('Bitcoin and ETH look strong today');
    assert.ok(found.includes('BTC'));
    assert.ok(found.includes('ETH'));
  });

  it('does not match partial words', () => {
    const found = extractSymbols('lets go shopping near the dogs park');
    assert.ok(!found.includes('DOGE'));
  });
});

describe('Validator', () => {
  it('returns a buy signal when market agrees', () => {
    const result = validateSignal(makeSignal(), { BTC: makeMarket() });
    assert.ok(result);
    assert.equal(result.symbol, 'BTC');
    assert.equal(result.direction, 'buy');
    assert.ok(result.probability >= 5 && result.probability <= 95);
    assert.equal(result.factors.length, 5);
  });

  it('computes exact buy and sell times', () => {
    const result = validateSignal(makeSignal(), { BTC: makeMarket() });
    const buyAt = new Date(result.buyAt);
    const sellAt = new Date(result.sellAt);
    assert.ok(!Number.isNaN(buyAt.getTime()));
    assert.ok(!Number.isNaN(sellAt.getTime()));
    assert.ok(sellAt > buyAt);
    assert.ok(sellAt - buyAt >= 45 * 60 * 1000);
    assert.ok(sellAt - buyAt <= 8 * 60 * 60 * 1000);
  });

  it('take profit is above entry for buys', () => {
    const result = validateSignal(makeSignal(), { BTC: makeMarket() });
    assert.ok(result.takeProfit > result.entry);
    assert.ok(result.stopLoss < result.entry);
  });
});
