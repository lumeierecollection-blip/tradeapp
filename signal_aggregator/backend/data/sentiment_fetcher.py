"""Retail sentiment fetcher — contrarian signal source.

Primary: Myfxbook Community Outlook (session-based API, 100 req/day free).
Fallback: ForexSentimentData.com scrape (no key, less reliable).

Output: dict {symbol: {'long_pct': float, 'short_pct': float, 'source': str}}
"""
import json
import os
import time
import requests

MYFXBOOK_EMAIL = os.environ.get('MYFXBOOK_EMAIL', '')
MYFXBOOK_PASSWORD = os.environ.get('MYFXBOOK_PASSWORD', '')
_CACHE = {}
_CACHE_AT = 0
_CACHE_TTL = 3600  # 1 hour


def _myfxbook_session():
    """Login and return session token, or None on failure."""
    if not MYFXBOOK_EMAIL or not MYFXBOOK_PASSWORD:
        return None
    try:
        r = requests.get(
            'https://www.myfxbook.com/api/login.json',
            params={'email': MYFXBOOK_EMAIL, 'password': MYFXBOOK_PASSWORD},
            timeout=15)
        data = r.json()
        return data.get('session')
    except Exception as e:
        print(f"[sentiment] myfxbook login failed: {e}")
        return None


def _myfxbook_outlook(session):
    """Fetch community outlook using a session token."""
    try:
        r = requests.get(
            'https://www.myfxbook.com/api/get-community-outlook.json',
            params={'session': session},
            timeout=20)
        data = r.json()
        outlook = data.get('outlook', [])
        result = {}
        for item in outlook:
            symbol = item.get('symbol', '').replace('/', '')
            long_pct = float(item.get('longPercentage', 0))
            short_pct = float(item.get('shortPercentage', 0))
            result[symbol] = {
                'long_pct': long_pct,
                'short_pct': short_pct,
                'source': 'myfxbook',
            }
        return result
    except Exception as e:
        print(f"[sentiment] myfxbook outlook failed: {e}")
        return {}


def _forex_sentiment_fallback():
    """Scrape ForexSentimentData.com as a fallback (no key required)."""
    # Placeholder — implement scrape if primary fails repeatedly.
    # Return empty dict for now; primary is the priority.
    return {}


def fetch_sentiment(force=False):
    """Return {symbol: {'long_pct':..,'short_pct':..,'source':..}}.
    Caches for 1 hour. Returns {} on total failure (never raises)."""
    global _CACHE, _CACHE_AT
    if not force and _CACHE and (time.time() - _CACHE_AT) < _CACHE_TTL:
        return _CACHE
    session = _myfxbook_session()
    result = {}
    if session:
        result = _myfxbook_outlook(session)
    if not result:
        result = _forex_sentiment_fallback()
    if result:
        _CACHE = result
        _CACHE_AT = time.time()
    return result


def get_contrarian_signal(symbol, threshold=70.0):
    """Return 'BUY', 'SELL', or None based on contrarian read.
    - >threshold% long  -> contrarian SELL (crowd is long)
    - >threshold% short -> contrarian BUY  (crowd is short)
    - otherwise         -> None (no edge)"""
    data = fetch_sentiment()
    # Normalize: myfxbook uses EURUSD, our symbols use EURUSD=X
    key = symbol.replace('=X', '').replace('/', '')
    info = data.get(key) or data.get(symbol)
    if not info:
        return None
    long_pct = info['long_pct']
    short_pct = info['short_pct']
    if long_pct >= threshold:
        return 'SELL'
    if short_pct >= threshold:
        return 'BUY'
    return None


if __name__ == '__main__':
    import pprint
    pprint.pprint(fetch_sentiment())
