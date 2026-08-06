import { readFile, writeFile } from 'node:fs/promises';

let admin = null;
let adminInitialized = false;
let adminError = null;

export function pushConfigured() {
  return Boolean(
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON ||
      process.env.GOOGLE_APPLICATION_CREDENTIALS,
  );
}

export async function initAdmin() {
  if (adminInitialized) return;
  adminInitialized = true;
  if (!pushConfigured()) {
    adminError = new Error(
      'FCM not configured (set FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS)',
    );
    return;
  }
  try {
    const module = await import('firebase-admin');
    admin = module.default ?? module;
    let credential;
    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
      credential = admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON));
    } else {
      credential = admin.credential.applicationDefault();
    }
    admin.initializeApp({ credential });
  } catch (err) {
    adminError = err;
    admin = null;
  }
}

export function pushEnabled() {
  return Boolean(admin) && adminInitialized && pushConfigured();
}

export function pushStatus() {
  if (!pushConfigured()) {
    return { enabled: false, reason: 'not-configured' };
  }
  if (adminInitialized && admin) {
    return { enabled: true };
  }
  return { enabled: false, reason: adminError ? String(adminError.message || adminError) : 'initializing' };
}

export async function sendPush(token, message) {
  await initAdmin();
  if (!pushEnabled()) {
    return { skipped: true, reason: pushStatus().reason || 'not configured' };
  }
  try {
    await admin.messaging().send({ token, ...message });
    return { ok: true };
  } catch (err) {
    return { error: String(err?.message || err) };
  }
}

export function signalKey(vs) {
  const id = vs?.signal?.id || '';
  return `${vs?.symbol || ''}-${id}`;
}

export function pushMessageFor(vs) {
  const direction =
    vs.direction === 'sell' ? 'SELL' : vs.direction === 'buy' ? 'BUY' : 'WATCH';
  return {
    notification: {
      title: `${direction} ${vs.symbol}`,
      body: signalBody(vs),
    },
    data: {
      type: 'signal',
      symbol: vs.symbol,
      direction: vs.direction,
      probability: String(Math.round(vs.probability)),
      entry: String(vs.entry),
      stopLoss: String(vs.stopLoss),
      takeProfit: String(vs.takeProfit),
      signalId: vs.signal?.id || '',
      sourceName: vs.signal?.sourceName || '',
      buyAt: vs.buyAt || '',
      sellAt: vs.sellAt || '',
    },
  };
}

function signalBody(vs) {
  if (vs.buyAt && vs.sellAt) {
    return `Rightness ${Math.round(vs.probability)}% · buy at ${clock(vs.buyAt)} · sell at ${clock(vs.sellAt)}.`;
  }
  return `Rightness ${Math.round(vs.probability)}% · entry ~${fmt(vs.entry)} · ${vs.entryWindow}.`;
}

function clock(value) {
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  const h = String(d.getHours()).padStart(2, '0');
  const m = String(d.getMinutes()).padStart(2, '0');
  return `${h}:${m}`;
}

export class PushNotifier {
  constructor({ tokenFile, seenFile, threshold = 70, sender = sendPush }) {
    this.tokenFile = tokenFile;
    this.seenFile = seenFile;
    this.threshold = threshold;
    this.sender = sender;
    this.tokens = [];
    this.seen = new Set();
    this.loaded = false;
  }

  async load() {
    const [tokens, seen] = await Promise.all([
      loadList(this.tokenFile),
      loadList(this.seenFile),
    ]);
    this.tokens = tokens;
    this.seen = new Set(seen);
    this.loaded = true;
  }

  register(token) {
    const clean = String(token || '').trim();
    if (!clean) return false;
    if (this.tokens.includes(clean)) return false;
    this.tokens.push(clean);
    void saveList(this.tokenFile, this.tokens);
    return true;
  }

  unregister(token) {
    const clean = String(token || '').trim();
    const before = this.tokens.length;
    this.tokens = this.tokens.filter((t) => t !== clean);
    if (this.tokens.length !== before) {
      void saveList(this.tokenFile, this.tokens);
    }
    return this.tokens.length !== before;
  }

  markSeen(validated) {
    let changed = false;
    for (const vs of validated) {
      if (vs.probability >= this.threshold && !this.seen.has(signalKey(vs))) {
        this.seen.add(signalKey(vs));
        changed = true;
      }
    }
    if (changed) {
      this.trimSeen();
      void saveList(this.seenFile, [...this.seen]);
    }
  }

  process(validated) {
    const fresh = [];
    for (const vs of validated) {
      if (vs.probability < this.threshold) continue;
      const key = signalKey(vs);
      if (this.seen.has(key)) continue;
      this.seen.add(key);
      fresh.push(vs);
    }
    if (fresh.length) {
      this.trimSeen();
      void saveList(this.seenFile, [...this.seen]);
    }
    return fresh;
  }

  async push(fresh) {
    if (!fresh.length || this.tokens.length === 0) return { attempted: 0, ok: 0 };
    let attempted = 0;
    let ok = 0;
    for (const vs of fresh) {
      const message = pushMessageFor(vs);
      for (const token of this.tokens) {
        attempted++;
        try {
          const result = await this.sender(token, message);
          if (result?.ok) ok++;
        } catch {
          // A failing device should not stop the rest.
        }
      }
    }
    return { attempted, ok };
  }

  trimSeen() {
    if (this.seen.size <= 5000) return;
    const list = [...this.seen];
    this.seen = new Set(list.slice(list.length - 5000));
  }
}

async function loadList(file) {
  if (!file) return [];
  try {
    const raw = await readFile(file, 'utf8');
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) return parsed.map((s) => String(s));
    return [];
  } catch {
    return [];
  }
}

async function saveList(file, list) {
  if (!file) return;
  try {
    await writeFile(file, JSON.stringify(list));
  } catch {
    // Persistence is best-effort.
  }
}

function fmt(v) {
  const n = Number(v);
  if (!Number.isFinite(n)) return String(v);
  return n >= 1000 ? n.toFixed(0) : n >= 1 ? n.toFixed(4) : n.toExponential(2);
}
