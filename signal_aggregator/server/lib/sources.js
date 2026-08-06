import { extractSymbols } from './symbols.js';

const REDDIT_SUBS = ['CryptoCurrency', 'CryptoMarkets', 'altcoin', 'Bitcoin', 'ethtrader'];

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
