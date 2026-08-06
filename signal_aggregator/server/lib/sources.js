import { extractSymbols } from './symbols.js';
import { toPair } from './pairs.js';

const REDDIT_SUBS = [
  'CryptoCurrency',
  'CryptoMarkets',
  'altcoin',
  'Bitcoin',
  'ethtrader',
  'ethereum',
  'Solana',
  'Chainlink',
  'dogecoin',
  'Tronix',
];

export async function fetchReddit() {
  const signals = [];
  await Promise.all(
    REDDIT_SUBS.map(async (sub) => {
      try {
        const res = await fetch(`https://www.reddit.com/r/${sub}/new.json?limit=20`, {
          headers: { 'User-Agent': 'signal-aggregator-android/1.0 (learning tool)' },
          signal: AbortSignal.timeout(25_000),
        });
        if (!res.ok) return;
        const body = await res.json();
        const children = body?.data?.children ?? [];
        for (const child of children) {
          const post = child?.data ?? {};
          const title = post.title ?? '';
          const selftext = post.selftext ?? '';
          const text = `${title} ${selftext}`;
          const symbols = extractSymbols(text);
          if (symbols.length === 0) continue;
          const created = Number(post.created_utc) || 0;
          signals.push({
            id: `reddit-${post.id}`,
            sourceKey: 'reddit',
            sourceName: `r/${sub}`,
            author: post.author ?? '',
            title,
            text: selftext,
            symbols,
            postedAt: created === 0 ? new Date().toISOString() : new Date(created * 1000).toISOString(),
            url: `https://www.reddit.com${post.permalink ?? ''}`,
          });
        }
      } catch {
        // Skip failing subreddits silently.
      }
    }),
  );
  return signals;
}

export async function fetchNews() {
  const signals = [];
  try {
    const res = await fetch('https://min-api.cryptocompare.com/data/v2/news/?lang=EN', {
      signal: AbortSignal.timeout(25_000),
    });
    if (!res.ok) return signals;
    const body = await res.json();
    const items = body?.Data ?? [];
    for (const item of items) {
      const title = item?.title ?? '';
      const bodyText = stripTags(item?.body ?? '');
      const text = `${title}. ${bodyText}`;
      const symbols = extractSymbols(text);
      if (symbols.length === 0) continue;
      const published = Number(item?.published_on) || 0;
      signals.push({
        id: `news-${item?.id}`,
        sourceKey: 'news',
        sourceName: item?.source_info?.name ?? 'News',
        author: '',
        title,
        text: bodyText,
        symbols,
        postedAt: published === 0 ? new Date().toISOString() : new Date(published * 1000).toISOString(),
        url: item?.url ?? '',
      });
    }
  } catch {
    // Ignore network errors; news is best-effort.
  }
  return signals;
}

export async function fetchTelegram(channels) {
  const signals = [];
  await Promise.all(
    channels.map(async (channel) => {
      try {
        const res = await fetch(`https://t.me/s/${channel}`, {
          headers: { 'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36' },
          signal: AbortSignal.timeout(25_000),
        });
        if (!res.ok) return;
        const html = await res.text();
        signals.push(...parseTelegramHtml(channel, html));
      } catch {
        // Channel may be private or preview unavailable.
      }
    }),
  );
  return signals;
}

function parseTelegramHtml(channel, html) {
  const signals = [];
  const regex =
    /<div class="tgme_widget_message[^"]*"[^>]*data-post="([^"]+)".*?<div class="tgme_widget_message_text[^"]*"[^>]*>(.*?)<\/div>/gs;
  for (const m of html.matchAll(regex)) {
    const rawText = cleanHtml(m[2] ?? '');
    if (!rawText) continue;
    const symbols = extractSymbols(rawText);
    if (symbols.length === 0) continue;
    signals.push({
      id: `tg-${m[1] ?? `${channel}-${signals.length}`}`,
      sourceKey: 'telegram',
      sourceName: `@${channel}`,
      author: `@${channel}`,
      title: '',
      text: rawText,
      symbols,
      postedAt: new Date().toISOString(),
      url: `https://t.me/${m[1] ?? channel}`,
    });
  }
  return signals;
}

function cleanHtml(html) {
  return html
    .replace(/<br\s*\/?>/g, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

function stripTags(html) {
  return String(html || '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export async function fetchRssNews() {
  const signals = [];
  try {
    const res = await fetch('https://www.coindesk.com/arc/outboundfeeds/rss/?outputType=xml', {
      signal: AbortSignal.timeout(25_000),
    });
    if (!res.ok) return signals;
    const xml = await res.text();
    const items = [...xml.matchAll(/<item>([\s\S]*?)<\/item>/g)];
    for (const match of items) {
      const block = match[1] ?? '';
      const title = tagText(block, 'title');
      const description = stripTags(tagText(block, 'description'));
      const text = `${title}. ${description}`;
      const symbols = extractSymbols(text);
      if (symbols.length === 0) continue;
      const link = tagText(block, 'link');
      const guid = tagText(block, 'guid') || link;
      signals.push({
        id: `rss-${hashCode(guid)}`,
        sourceKey: 'rss',
        sourceName: 'CoinDesk news',
        author: '',
        title,
        text: description,
        symbols,
        postedAt: rfc822Date(tagText(block, 'pubDate')).toISOString(),
        url: link,
      });
    }
  } catch {
    // RSS is best-effort; a bad feed must never break the scan.
  }
  return signals;
}

function tagText(block, tag) {
  const m = block.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`, 'i'));
  return m ? decodeXml(m[1]).trim() : '';
}

function decodeXml(s) {
  return String(s || '')
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function rfc822Date(raw) {
  const d = new Date(raw || '');
  return Number.isNaN(d.getTime()) ? new Date() : d;
}

function hashCode(s) {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = (Math.imul(31, h) + s.charCodeAt(i)) | 0;
  }
  return (h & 0x7fffffff).toString(36);
}

export function generatePulseSignals(markets) {
  const signals = [];
  const now = Date.now();
  for (const symbol of Object.keys(markets)) {
    const m = markets[symbol];
    const setup = pulseSetup(m);
    if (!setup) continue;
    signals.push({
      id: `pulse-${symbol}-${now}`,
      sourceKey: 'pulse',
      sourceName: 'Market pulse',
      author: '',
      title: setup.title,
      text: setup.text,
      symbols: [symbol],
      postedAt: new Date().toISOString(),
      url: '',
    });
  }
  return signals;
}

function pulseSetup(m) {
  const push = m.change5m;
  const drift = m.change1h;
  const vol = volumeRatioOf(m);
  const pct = (v) => `${v.toFixed(1)}%`;
  const price = (v) => (v >= 1000 ? v.toFixed(0) : v >= 1 ? v.toFixed(4) : v.toExponential(2));

  if (drift < -0.4 && m.rsi14 < 45 && m.nearSupport && vol > 1.0) {
    return {
      title: `Market pulse: ${m.symbol} pullback buy setup`,
      text:
        `Bullish setup. ${m.symbol} pulled back ${pct(drift)} over the last hour toward support ` +
        `(${price(m.support)}) with volume at ${vol.toFixed(1)}x normal. ` +
        `RSI (${Math.round(m.rsi14)}) is getting oversold, so sellers look tired. ` +
        `Buy the dip, accumulate with a stop below support, expect upside to ${price(m.resistance)}.`,
    };
  }
  if (drift > 0.3 && vol > 1.5 && m.rsi14 < 70 && !m.nearResistance) {
    return {
      title: `Market pulse: ${m.symbol} breakout setup`,
      text:
        `Bullish setup. ${m.symbol} is breaking out with volume at ${vol.toFixed(1)}x normal ` +
        `and momentum of ${pct(drift)} in the last hour. RSI (${Math.round(m.rsi14)}) still has ` +
        `room before overbought. Buy on strength, stop below the breakout level, ` +
        `target the next resistance at ${price(m.resistance)}.`,
    };
  }
  if (drift > 0.5 && m.rsi14 > 62 && m.nearResistance && vol > 1.0) {
    return {
      title: `Market pulse: ${m.symbol} rejection setup`,
      text:
        `Bearish setup. ${m.symbol} rallied ${pct(drift)} and is now hitting resistance ` +
        `(${price(m.resistance)}) with RSI (${Math.round(m.rsi14)}) overbought. ` +
        `Buyers look exhausted — expect a downside pullback and a correction. ` +
        `Take profit on longs, or short with a stop above resistance.`,
    };
  }
  if (drift < -0.3 && push < -0.3 && vol > 1.5 && m.rsi14 > 50) {
    return {
      title: `Market pulse: ${m.symbol} breakdown setup`,
      text:
        `Bearish setup. ${m.symbol} is breaking down with volume at ${vol.toFixed(1)}x normal ` +
        `and downside momentum building (${pct(drift)} in the last hour). ` +
        `Expect lower prices toward ${price(m.support)} — avoid longs and stay out of the way.`,
    };
  }
  return null;
}

function volumeRatioOf(m) {
  if (typeof m.volumeRatio === 'number' && Number.isFinite(m.volumeRatio)) return m.volumeRatio;
  return m.avgVolume <= 0 ? 1 : m.volume24h / m.avgVolume;
}
