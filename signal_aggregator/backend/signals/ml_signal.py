"""Live signal generator using trained LightGBM model.
Run daily. Output matches the schema the Flutter app already reads."""
import json
import os
import sys
from datetime import datetime, UTC

import numpy as np
import pandas as pd
import yfinance as yf
import lightgbm as lgb

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
from backend.data.cross_asset_fetcher import fetch_cross_asset
from backend.ml.features import build_features
from backend.ml.regime import classify_regime

SYMBOLS = [
    'EURUSD=X', 'GBPUSD=X', 'USDJPY=X', 'AUDUSD=X', 'NZDUSD=X',
    'GBPJPY=X', 'EURJPY=X', 'AUDJPY=X', 'USDCAD=X',
    'GC=F', 'SI=F', 'CL=F', 'NG=F',
    'BTC-USD', 'ETH-USD',
    '^GSPC', '^NDX',
]

LABEL_MAP = {0: 'SELL', 1: 'HOLD', 2: 'BUY'}


def load_model(symbol):
    safe = symbol.replace('=', '_').replace('^', '')
    path = f'signal_aggregator/data/ml/{safe}_model.txt'
    if not os.path.exists(path):
        return None
    booster = lgb.Booster(model_file=path)
    return booster


def build_live_features(symbol, cross):
    df = yf.download(symbol, period='1y', interval='1d',
                     progress=False, auto_adjust=True)
    if hasattr(df.columns, 'get_level_values'):
        df.columns = df.columns.get_level_values(0)
    df.columns = [c.lower() for c in df.columns]
    feats = build_features(df, cross)
    return feats, df


def main():
    cross = fetch_cross_asset()
    results = []
    for symbol in SYMBOLS:
        try:
            booster = load_model(symbol)
            if booster is None:
                results.append({'symbol': symbol, 'signal': 'HOLD',
                                'confidence': 0.0, 'price': 0.0,
                                'error': 'no trained model'})
                continue
            feats, raw = build_live_features(symbol, cross)
            if feats.empty:
                results.append({'symbol': symbol, 'signal': 'HOLD',
                                'confidence': 0.0, 'price': 0.0,
                                'error': 'no features'})
                continue

            feature_cols = booster.feature_name()
            X = feats.iloc[[-1]][feature_cols]
            probs = booster.predict(X)[0]
            pred_class = int(np.argmax(probs))
            confidence = float(probs[pred_class])

            regime = classify_regime(feats).iloc[-1]
            price = float(raw['close'].iloc[-1])

            signal = LABEL_MAP[pred_class]
            if regime == 'vol' and signal != 'HOLD':
                signal = 'HOLD'
                confidence = min(confidence, 0.5)

            results.append({
                'symbol': symbol,
                'signal': signal,
                'confidence': round(confidence, 4),
                'price': price,
                'regime': regime,
                'generated_at': datetime.now(UTC).isoformat(),
            })
        except Exception as e:
            results.append({'symbol': symbol, 'signal': 'HOLD',
                            'confidence': 0.0, 'price': 0.0,
                            'error': str(e)[:200]})

    out = {
        'timestamp': datetime.now(UTC).isoformat(),
        'model': 'lightgbm_v1',
        'signals': results,
    }
    os.makedirs('signal_aggregator/data/signals', exist_ok=True)
    with open('signal_aggregator/data/signals/ml_latest.json', 'w') as f:
        json.dump(out, f, indent=2)

    print(f"Generated {len(results)} signals")
    for r in results[:5]:
        print(f"  {r['symbol']}: {r['signal']} ({r.get('confidence', 0):.2f}) regime={r.get('regime', '?')}")


if __name__ == '__main__':
    main()
