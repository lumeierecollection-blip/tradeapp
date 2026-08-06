import http from 'node:http';
import { resolve } from 'node:path';

import { fetchSnapshots } from './lib/market.js';
import { PushNotifier, pushConfigured, pushStatus } from './lib/push.js';
import { fetchNews, fetchReddit, fetchTelegram } from './lib/sources.js';
import { validateSignal } from './lib/validator.js';

const PORT = Number(process.env.PORT || 8080);
const CACHE_TTL_MS = Number(process.env.CACHE_TTL_MS || 10 * 60 * 1000);
const SCAN_INTERVAL_MS = Number(process.env.SCAN_INTERVAL_MS || 5 * 60 * 1000);
const MIN_PROBABILITY = Number(process.env.MIN_PROBABILITY || 70);
const DEVICE_TOKENS_FILE =
  process.env.DEVICE_TOKENS_FILE || resolve(process.cwd(), 'device_tokens.json');
const SEEN_SIGNALS_FILE =
  process.env.SEEN_SIGNALS_FILE || resolve(process.cwd(), 'seen_signals.json');

const WATCHLIST = splitEnv(process.env.WATCHLIST, ['BTC', 'ETH', 'SOL', 'BNB', 'XRP']);
const TELEGRAM_CHANNELS = splitEnv(process.env.TELEGRAM_CHANNELS, [
  'BitcoinBullets',
  'fatpigsignals',
  'learn2trade',
  'cryptoinnercircle',
  'binancesignals',
]);
const ENABLED_SOURCES = new Set(
  splitEnv(process.env.ENABLED_SOURCES, ['reddit', 'news', 'telegram']),
);

let cache = { generatedAt: null, validated: [], markets: {}, signals: [], running: false };
let scanChain = Promise.resolve();
let bootstrapped = false;

const notifier = new PushNotifier({
  tokenFile: DEVICE_TOKENS_FILE,
  seenFile: SEEN_SIGNALS_FILE,
  threshold: MIN_PROBABILITY,
});

async function scan() {
  if (cache.running) return scanChain;
  const job = (async () => {
    cache.running = true;
    try {
      const fetchers = [];
      if (ENABLED_SOURCES.has('reddit')) fetchers.push(fetchReddit());
      if (ENABLED_SOURCES.has('news')) fetchers.push(fetchNews());
      if (ENABLED_SOURCES.has('telegram')) fetchers.push(fetchTelegram(TELEGRAM_CHANNELS));

      const batches = await Promise.allSettled(fetchers);
      const signals = [];
      const seen = new Set();
      for (const batch of batches) {
        if (batch.status !== 'fulfilled') continue;
        for (const signal of batch.value) {
          if (!seen.has(signal.id)) {
            seen.add(signal.id);
            signals.push(signal);
          }
        }
      }
      signals.sort((a, b) => new Date(b.postedAt) - new Date(a.postedAt));

      const symbolSet = new Set(WATCHLIST);
      for (const s of signals) {
        for (const sym of s.symbols) symbolSet.add(sym);
      }
      const markets = await fetchSnapshots([...symbolSet].slice(0, 20));

      const validated = [];
      for (const signal of signals) {
        const vs = validateSignal(signal, markets);
        if (vs) validated.push(vs);
      }
      validated.sort((a, b) => b.probability - a.probability);

      cache = {
        generatedAt: new Date().toISOString(),
        validated,
        markets,
        signals,
        running: false,
      };

      if (bootstrapped) {
        const fresh = notifier.process(validated);
        if (fresh.length) {
          const { attempted, ok } = await notifier.push(fresh);
          console.log(
            `[push] ${fresh.length} new signal(s) · ${ok}/${attempted} delivered`,
          );
        }
      }
    } finally {
      cache.running = false;
    }
  })();
  scanChain = job;
  return job;
}

function payload() {
  return {
    generatedAt: cache.generatedAt,
    cloud: true,
    validated: cache.validated,
    signals: cache.signals,
    markets: cache.markets,
  };
}

async function handle(req, res) {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const path = url.pathname;

  setCors(req, res);

  try {
    if (req.method === 'GET' && path === '/api/health') {
      return json(res, 200, {
        ok: true,
        service: 'signal-aggregator-backend',
        uptime: Math.round(process.uptime()),
      });
    }

    if (req.method === 'GET' && path === '/api/status') {
      const push = pushStatus();
      return json(res, 200, {
        service: 'signal-aggregator-backend',
        uptime: Math.round(process.uptime()),
        scanIntervalMs: SCAN_INTERVAL_MS,
        minProbability: MIN_PROBABILITY,
        generatedAt: cache.generatedAt,
        validatedCount: cache.validated.length,
        pushConfigured: pushConfigured(),
        pushEnabled: push.enabled,
        pushReason: push.reason ?? null,
        deviceCount: notifier.tokens.length,
        seenCount: notifier.seen.size,
      });
    }

    if (req.method === 'POST' && path === '/api/device/register') {
      const body = await readJsonBody(req);
      const token = String(body.token || '').trim();
      if (!token) return json(res, 400, { error: 'token required' });
      notifier.register(token);
      return json(res, 200, { ok: true, devices: notifier.tokens.length });
    }

    if (req.method === 'POST' && path === '/api/device/unregister') {
      const body = await readJsonBody(req);
      const token = String(body.token || '').trim();
      if (!token) return json(res, 400, { error: 'token required' });
      const removed = notifier.unregister(token);
      return json(res, 200, { ok: true, removed, devices: notifier.tokens.length });
    }

    if (req.method === 'GET' && path === '/api/signals') {
      const stale =
        !cache.generatedAt || Date.now() - new Date(cache.generatedAt).getTime() > CACHE_TTL_MS;
      if (stale) {
        await scan();
      }
      return json(res, 200, payload());
    }

    if (req.method === 'POST' && path === '/refresh') {
      await scan();
      return json(res, 200, {
        ok: true,
        generatedAt: cache.generatedAt,
        signalCount: cache.signals.length,
        validatedCount: cache.validated.length,
        top: cache.validated[0]
          ? {
              symbol: cache.validated[0].symbol,
              direction: cache.validated[0].direction,
              probability: cache.validated[0].probability,
            }
          : null,
      });
    }

    if (req.method === 'GET' && (path === '/' || path === '')) {
      return json(res, 200, {
        service: 'signal-aggregator-backend',
        endpoints: [
          'GET /api/signals',
          'GET /api/status',
          'GET /api/health',
          'POST /api/device/register',
          'POST /api/device/unregister',
          'POST /refresh',
        ],
      });
    }

    return json(res, 404, { error: 'Not found' });
  } catch (err) {
    return json(res, 500, { error: String(err && err.message ? err.message : err) });
  }
}

function setCors(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
  }
}

function json(res, status, body) {
  const text = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(text),
  });
  res.end(text);
}

async function readJsonBody(req) {
  const raw = await readBody(req);
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.setEncoding('utf8');
    req.on('data', (chunk) => {
      data += chunk;
      if (data.length > 8192) {
        req.destroy();
        reject(new Error('Body too large'));
      }
    });
    req.on('end', () => resolve(data));
    req.on('error', reject);
  });
}

function splitEnv(raw, fallback) {
  if (!raw) return fallback;
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

async function bootstrap() {
  await notifier.load();
  await scan();
  notifier.markSeen(cache.validated);
  bootstrapped = true;
  setInterval(async () => {
    try {
      await scan();
    } catch (err) {
      console.error('scan failed:', err?.message || err);
    }
  }, SCAN_INTERVAL_MS);
  console.log(
    `scanner: every ${Math.round(SCAN_INTERVAL_MS / 1000)}s · threshold ${MIN_PROBABILITY}% · ` +
      `push ${pushConfigured() ? 'configured' : 'DISABLED (no Firebase credentials)'} · ` +
      `${notifier.tokens.length} device(s)`,
  );
}

const server = http.createServer(handle);
server.listen(PORT, () => {
  console.log(`signal-aggregator-backend listening on :${PORT}`);
  void bootstrap();
});
