const SYMBOL_TO_PAIR = {
  BTC: 'BTCUSDT',
  ETH: 'ETHUSDT',
  SOL: 'SOLUSDT',
  BNB: 'BNBUSDT',
  XRP: 'XRPUSDT',
  ADA: 'ADAUSDT',
  DOGE: 'DOGEUSDT',
  AVAX: 'AVAXUSDT',
  LINK: 'LINKUSDT',
  DOT: 'DOTUSDT',
  MATIC: 'MATICUSDT',
  LTC: 'LTCUSDT',
  UNI: 'UNIUSDT',
  ARB: 'ARBUSDT',
  OP: 'OPUSDT',
  SHIB: 'SHIBUSDT',
  TRX: 'TRXUSDT',
  NEAR: 'NEARUSDT',
  APT: 'APTUSDT',
  FIL: 'FILUSDT',
};

export function toPair(symbol) {
  return SYMBOL_TO_PAIR[String(symbol || '').toUpperCase()] || null;
}
