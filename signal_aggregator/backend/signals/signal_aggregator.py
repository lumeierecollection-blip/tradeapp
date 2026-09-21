import json
import os
import sys
from datetime import datetime, timezone

import yfinance as yf

# Ensure backend/ is on sys.path so 'data.*' and 'sentiment.*' resolve
_BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if _BACKEND_DIR not in sys.path:
    sys.path.insert(0, _BACKEND_DIR)
from data.sentiment_fetcher import get_contrarian_signal, fetch_sentiment

# --- Strategy weights (loaded from persistence or defaults) ---
_WEIGHTS_PATH = os.path.join(os.path.dirname(__file__), '..', '..', 'data', 'strategy_weights.json')
_STRATEGY_WEIGHTS = {"ma_cross": 1.0, "rsi_bollinger": 1.0, "vwap_bollinger": 1.0}


def _load_weights():
    global _STRATEGY_WEIGHTS
    try:
        with open(_WEIGHTS_PATH) as f:
            _STRATEGY_WEIGHTS = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        pass


def _save_weights():
    os.makedirs(os.path.dirname(_WEIGHTS_PATH), exist_ok=True)
    with open(_WEIGHTS_PATH, 'w') as f:
        json.dump(_STRATEGY_WEIGHTS, f, indent=2)


def update_weights_from_backtest():
    # TODO: implement weight update rule from historical backtest results
    pass


# --- Sentiment scorer (graceful fallback if finbert unavailable) ---
def _sentiment_score(text):
    try:
        from sentiment.finbert_scorer import score as _score
        return _score(text)
    except Exception:
        return {"label": "neutral", "score": 0.5}


def _fetch_news_headlines(symbol):
    try:
        ticker = yf.Ticker(symbol)
        news = ticker.news or []
        headlines = []
        for item in news[:5]:
            title = item.get('title', '')
            if title:
                headlines.append(title)
        return headlines
    except Exception:
        return []


def _compute_sentiment(symbol):
    headlines = _fetch_news_headlines(symbol)
    if not headlines:
        return {"label": "neutral", "score": 0.5, "value": 0.0}
    combined = " ".join(headlines)
    result = _sentiment_score(combined)
    value = 0.0
    if result["label"] == "positive":
        value = result["score"]
    elif result["label"] == "negative":
        value = -result["score"]
    result["value"] = round(value, 3)
    return result


# --- Multi-timeframe trend filter ---
def _compute_daily_trend(symbol):
    """Returns (trend_up, trend_down) booleans based on Daily SMA_50."""
    try:
        ticker = yf.Ticker(symbol)
        daily = ticker.history(period='6mo', interval='1d')
        if daily.empty or len(daily) < 50:
            return False, False
        close = daily['Close']
        sma50 = close.rolling(50).mean().iloc[-1]
        last_close = close.iloc[-1]
        return (last_close > sma50, last_close < sma50)
    except Exception:
        return False, False


# --- Strategy functions (unchanged interface) ---
def fetch_price(symbol):
    try:
        ticker = yf.Ticker(symbol)
        hist = ticker.history(period='1d')
        if not hist.empty:
            return hist['Close'].iloc[-1]
    except Exception:
        pass
    return 0.0


def check_ma_cross(symbol, short_period=5, long_period=20):
    try:
        ticker = yf.Ticker(symbol)
        hist = ticker.history(period='6mo', interval='1d')
        if hist.empty or len(hist) < long_period:
            return 'HOLD'
        close = hist['Close']
        short_ma = close.rolling(short_period).mean().iloc[-1]
        long_ma = close.rolling(long_period).mean().iloc[-1]
        if short_ma > long_ma:
            return 'BUY'
        elif short_ma < long_ma:
            return 'SELL'
    except Exception:
        pass
    return 'HOLD'


def check_rsi_bollinger(symbol, rsi_period=14, rsi_upper=70, rsi_lower=30):
    try:
        ticker = yf.Ticker(symbol)
        hist = ticker.history(period='3mo', interval='1d')
        if hist.empty or len(hist) < rsi_period + 1:
            return 'HOLD'
        close = hist['Close']
        delta = close.diff()
        gain = (delta.where(delta > 0, 0)).rolling(rsi_period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(rsi_period).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        last_rsi = rsi.iloc[-1]
        mean = close.mean()
        std = close.std()
        upper = mean + (2 * std)
        lower = mean - (2 * std)
        if last_rsi > rsi_upper:
            return 'SELL'
        elif last_rsi < rsi_lower:
            return 'BUY'
        elif close.iloc[-1] > upper:
            return 'SELL'
        elif close.iloc[-1] < lower:
            return 'BUY'
    except Exception:
        pass
    return 'HOLD'


def check_vwap_bollinger(symbol):
    try:
        ticker = yf.Ticker(symbol)
        hist = ticker.history(period='1mo', interval='30m')
        if hist.empty or len(hist) < 20:
            return 'HOLD'
        typical_price = (hist['High'] + hist['Low'] + hist['Close']) / 3
        vwap = (typical_price * hist['Volume']).cumsum() / hist['Volume'].cumsum()
        mean = vwap.mean()
        std = vwap.std()
        upper = mean + (2 * std)
        lower = mean - (2 * std)
        last_vwap = vwap.iloc[-1]
        last_price = hist['Close'].iloc[-1]
        if last_price > upper:
            return 'SELL'
        elif last_price < lower:
            return 'BUY'
        elif last_vwap > mean:
            return 'BUY'
        elif last_vwap < mean:
            return 'SELL'
    except Exception:
        pass
    return 'HOLD'


# --- Weighted ensemble ---
def _weighted_vote(strategies, weights):
    buy_score = 0.0
    sell_score = 0.0
    for name, signal in strategies.items():
        w = weights.get(name, 1.0)
        if signal == 'BUY':
            buy_score += w
        elif signal == 'SELL':
            sell_score += w
    if buy_score > sell_score + 0.5:
        return 'BUY', buy_score, sell_score
    elif sell_score > buy_score + 0.5:
        return 'SELL', buy_score, sell_score
    return 'HOLD', buy_score, sell_score


def determine_signals(symbol='EURUSD=X'):
    _load_weights()

    strategies = {
        'ma_cross': check_ma_cross(symbol),
        'rsi_bollinger': check_rsi_bollinger(symbol),
        'vwap_bollinger': check_vwap_bollinger(symbol),
    }

    raw_signal, buy_score, sell_score = _weighted_vote(strategies, _STRATEGY_WEIGHTS)

    # Multi-timeframe trend filter
    trend_up, trend_down = _compute_daily_trend(symbol)
    filtered_reason = None
    if raw_signal == 'BUY' and not trend_up:
        filtered_reason = 'counter-trend, filtered'
        final_signal = 'HOLD'
    elif raw_signal == 'SELL' and not trend_down:
        filtered_reason = 'counter-trend, filtered'
        final_signal = 'HOLD'
    else:
        final_signal = raw_signal

    # Retail sentiment contrarian filter (informational + optional gate)
    contra = get_contrarian_signal(symbol)
    if contra and final_signal != 'HOLD' and contra != final_signal:
        filtered_reason = f"retail crowd {contra} signal conflict"
        final_signal = 'HOLD'

    # Sentiment (informational only)
    sentiment = _compute_sentiment(symbol)

    # Retail sentiment data for output
    retail_data = fetch_sentiment()
    retail_key = symbol.replace('=X', '').replace('/', '')
    retail_sentiment = retail_data.get(retail_key) or retail_data.get(symbol) or {}

    price = fetch_price(symbol)

    hist = yf.Ticker(symbol).history(period='1d')
    latest = datetime.fromtimestamp(
        int(hist.index[-1].timestamp())
    ) if not hist.empty else datetime.now(timezone.utc)

    result = {
        'timestamp': latest.strftime('%Y-%m-%dT%H:%M:%SZ'),
        'signals': [
            {
                'symbol': symbol,
                'signal': final_signal,
                'confidence': round(0.5 + (buy_score - sell_score) * 0.15, 2),
                'price': round(price, 4),
                'strategies': strategies,
                'filtered_reason': filtered_reason,
                'sentiment': sentiment,
                'retail_sentiment': retail_sentiment,
            }
        ],
    }

    os.makedirs(os.path.dirname('signal_aggregator/data/signals/latest.json'), exist_ok=True)
    with open('signal_aggregator/data/signals/latest.json', 'w') as f:
        json.dump(result, f, indent=2)

    _save_weights()
    return result


if __name__ == '__main__':
    symbols = [
        'EURUSD=X', 'GBPUSD=X', 'USDJPY=X', 'AUDUSD=X',
        'GBPJPY=X', 'EURJPY=X', 'AUDJPY=X', 'NZDUSD=X', 'USDCAD=X',
        'GC=F', 'SI=F', 'CL=F', 'NG=F',
        'BTC-USD', 'ETH-USD', 'SOL-USD', 'BNB-USD',
        '^GSPC', '^NDX', '^RUT',
    ]
    all_signals = []
    for sym in symbols:
        result = determine_signals(sym)
        all_signals.extend(result.get('signals', []))
    combined = {
        'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'signals': all_signals,
    }
    os.makedirs('signal_aggregator/data/signals', exist_ok=True)
    with open('signal_aggregator/data/signals/latest.json', 'w') as f:
        json.dump(combined, f, indent=2)
    print(f'Generated {len(all_signals)} signals')
