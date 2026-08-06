import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { PushNotifier, pushMessageFor, signalKey } from '../lib/push.js';

function makeVs(overrides = {}) {
  return {
    symbol: 'BTC',
    direction: 'buy',
    probability: 82,
    entry: 61234.5,
    stopLoss: 60000,
    takeProfit: 62800,
    entryWindow: 'window is open now',
    buyAt: '2026-08-06T14:30:00.000Z',
    sellAt: '2026-08-06T17:05:00.000Z',
    signal: { id: 'reddit-abc', sourceName: 'r/Bitcoin' },
    ...overrides,
  };
}

describe('pushMessageFor', () => {
  it('builds an FCM payload', () => {
    const msg = pushMessageFor(makeVs());
    assert.equal(msg.notification.title, 'BUY BTC');
    assert.match(msg.notification.body, /82%/);
    assert.match(msg.notification.body, /buy at/);
    assert.equal(msg.data.type, 'signal');
    assert.equal(msg.data.symbol, 'BTC');
    assert.equal(msg.data.probability, '82');
    assert.equal(msg.data.signalId, 'reddit-abc');
    assert.equal(msg.data.buyAt, '2026-08-06T14:30:00.000Z');
    assert.equal(msg.data.sellAt, '2026-08-06T17:05:00.000Z');
  });

  it('falls back to entry window when no times are set', () => {
    const msg = pushMessageFor(makeVs({ buyAt: undefined, sellAt: undefined }));
    assert.match(msg.notification.body, /window is open now/);
  });

  it('labels sells', () => {
    const msg = pushMessageFor(makeVs({ direction: 'sell' }));
    assert.equal(msg.notification.title, 'SELL BTC');
  });
});

describe('signalKey', () => {
  it('combines symbol and source id', () => {
    assert.equal(signalKey(makeVs()), 'BTC-reddit-abc');
  });
});

describe('PushNotifier', () => {
  async function makeNotifier() {
    const dir = await mkdtemp(join(tmpdir(), 'push-test-'));
    const notifier = new PushNotifier({
      tokenFile: join(dir, 'tokens.json'),
      seenFile: join(dir, 'seen.json'),
      threshold: 70,
      sender: async () => ({ ok: true }),
    });
    await notifier.load();
    return { notifier, dir };
  }

  it('registers and unregisters device tokens', async () => {
    const { notifier, dir } = await makeNotifier();
    try {
      assert.equal(notifier.register(' token-1 '), true);
      assert.equal(notifier.register('token-1'), false); // duplicate
      assert.deepEqual(notifier.tokens, ['token-1']);
      assert.equal(notifier.unregister('token-1'), true);
      assert.deepEqual(notifier.tokens, []);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });

  it('only surfaces new signals above the threshold once', async () => {
    const { notifier, dir } = await makeNotifier();
    try {
      const low = makeVs({ signal: { id: 'low' }, probability: 50 });
      const first = makeVs({ signal: { id: 'first' }, probability: 80 });
      const second = makeVs({ signal: { id: 'second' }, probability: 90 });

      assert.deepEqual(notifier.process([low, first]), [first]);
      assert.deepEqual(notifier.process([low, first, second]), [second]);
      assert.deepEqual(notifier.process([second]), []);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });

  it('markSeen seeds without notifying', async () => {
    const { notifier, dir } = await makeNotifier();
    try {
      const existing = makeVs();
      notifier.markSeen([existing]);
      assert.deepEqual(notifier.process([existing]), []);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });

  it('delivers to every registered device', async () => {
    const sent = [];
    const dir = await mkdtemp(join(tmpdir(), 'push-test-'));
    try {
      const notifier = new PushNotifier({
        tokenFile: join(dir, 'tokens.json'),
        seenFile: join(dir, 'seen.json'),
        threshold: 70,
        sender: async (token, message) => {
          sent.push({ token, title: message.notification.title });
          return { ok: true };
        },
      });
      await notifier.load();
      notifier.register('device-a');
      notifier.register('device-b');
      const result = await notifier.push([makeVs()]);
      assert.equal(result.attempted, 2);
      assert.equal(result.ok, 2);
      assert.deepEqual(sent.map((s) => s.token), ['device-a', 'device-b']);
      assert.equal(sent[0].title, 'BUY BTC');
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });
});
