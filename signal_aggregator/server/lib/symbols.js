import { toPair } from './pairs.js';

const ALIASES = {
  bitcoin: 'BTC',
  btc: 'BTC',
  ethereum: 'ETH',
  ether: 'ETH',
  eth: 'ETH',
  solana: 'SOL',
  sol: 'SOL',
  bnb: 'BNB',
  'binance coin': 'BNB',
  xrp: 'XRP',
  ripple: 'XRP',
  cardano: 'ADA',
  ada: 'ADA',
  dogecoin: 'DOGE',
  doge: 'DOGE',
  avalanche: 'AVAX',
  avax: 'AVAX',
  chainlink: 'LINK',
  link: 'LINK',
  polkadot: 'DOT',
  dot: 'DOT',
  polygon: 'MATIC',
  matic: 'MATIC',
  litecoin: 'LTC',
  ltc: 'LTC',
  uniswap: 'UNI',
  uni: 'UNI',
  arbitrum: 'ARB',
  arb: 'ARB',
  optimism: 'OP',
  shiba: 'SHIB',
  shib: 'SHIB',
  'shiba inu': 'SHIB',
  tron: 'TRX',
  trx: 'TRX',
  near: 'NEAR',
  'near protocol': 'NEAR',
  aptos: 'APT',
  apt: 'APT',
  filecoin: 'FIL',
  fil: 'FIL',
};

export function extractSymbols(text) {
  const found = new Map();
  const lower = String(text || '').toLowerCase();

  for (const [word, symbol] of Object.entries(ALIASES)) {
    if (!toPair(symbol)) continue;
    if (containsWord(lower, word)) found.set(symbol, true);
  }

  const regex = /#?[$]?\b([A-Za-z]{2,8})\b(USDT|USD)?/gi;
  for (const m of text.matchAll(regex)) {
    const candidate = m[1].toUpperCase();
    if (toPair(candidate)) found.set(candidate, true);
  }

  return [...found.keys()];
}

function containsWord(lower, word) {
  let index = lower.indexOf(word);
  while (index !== -1) {
    const beforeOk = index === 0 || !isAlphaNumeric(lower[index - 1]);
    const afterIndex = index + word.length;
    const afterOk = afterIndex >= lower.length || !isAlphaNumeric(lower[afterIndex]);
    if (beforeOk && afterOk) return true;
    const next = lower.indexOf(word, index + 1);
    if (next === index) break;
    index = next;
  }
  return false;
}

function isAlphaNumeric(ch) {
  const code = ch.charCodeAt(0);
  return (
    (code >= 48 && code <= 57) ||
    (code >= 65 && code <= 90) ||
    (code >= 97 && code <= 122)
  );
}
