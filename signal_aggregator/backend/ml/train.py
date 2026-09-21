"""Train a LightGBM classifier on engineered features.
Walk-forward: train on N months, predict next M months, roll forward."""
import json
import os
import sys
from datetime import datetime, UTC

import numpy as np
import pandas as pd
import yfinance as yf

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
from backend.data.cross_asset_fetcher import fetch_cross_asset
from backend.ml.features import build_features, make_labels
from backend.ml.regime import classify_regime

try:
    import lightgbm as lgb
except ImportError:
    print("ERROR: pip install lightgbm")
    sys.exit(1)


def load_ohlcv(symbol, period='2y', interval='1d'):
    df = yf.download(symbol, period=period, interval=interval,
                     progress=False, auto_adjust=True)
    if hasattr(df.columns, 'get_level_values'):
        df.columns = df.columns.get_level_values(0)
    df.columns = [c.lower() for c in df.columns]
    return df


def train_symbol(symbol, train_bars=250, test_bars=60, step=60):
    ohlcv = load_ohlcv(symbol)
    if ohlcv.empty or len(ohlcv) < train_bars + test_bars:
        return {'symbol': symbol, 'windows': [], 'avg_accuracy': None,
                'error': f'insufficient data ({len(ohlcv)} bars)'}
    cross = fetch_cross_asset()
    feats = build_features(ohlcv, cross)
    labels = make_labels(feats)

    feature_cols = [c for c in feats.columns
                    if c not in ('open', 'high', 'low', 'close', 'volume', 'timestamp')]

    results = []
    i = 0
    model = None
    while i + train_bars + test_bars <= len(feats):
        train_X = feats.iloc[i:i+train_bars][feature_cols]
        train_y = labels.iloc[i:i+train_bars]
        test_X  = feats.iloc[i+train_bars:i+train_bars+test_bars][feature_cols]
        test_y  = labels.iloc[i+train_bars:i+train_bars+test_bars]

        train_y_m = (train_y + 1).astype(int)
        test_y_m  = (test_y  + 1).astype(int)

        model = lgb.LGBMClassifier(
            n_estimators=200, max_depth=5, learning_rate=0.05,
            num_leaves=31, min_child_samples=20, verbose=-1
        )
        model.fit(train_X, train_y_m)

        preds = model.predict(test_X)
        acc = (preds == test_y_m).mean()

        results.append({
            'window_start': str(feats.index[i+train_bars].date()),
            'window_end':   str(feats.index[i+train_bars+test_bars-1].date()),
            'accuracy': round(float(acc), 4),
            'test_size': int(len(test_y_m)),
        })
        i += step

    if not results:
        return {'symbol': symbol, 'windows': [], 'avg_accuracy': None}

    avg_acc = float(np.mean([r['accuracy'] for r in results]))

    out = {
        'symbol': symbol,
        'trained_at': datetime.now(UTC).isoformat(),
        'n_features': len(feature_cols),
        'feature_cols': feature_cols,
        'avg_accuracy': round(avg_acc, 4),
        'windows': results,
    }

    os.makedirs('signal_aggregator/data/ml', exist_ok=True)
    safe = symbol.replace('=', '_').replace('^', '')
    path = f'signal_aggregator/data/ml/{safe}.json'
    with open(path, 'w') as f:
        json.dump(out, f, indent=2)

    if model is not None:
        model_path = f'signal_aggregator/data/ml/{safe}_model.txt'
        model.booster_.save_model(model_path)

    return out


if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('--symbol', default='EURUSD=X')
    args = p.parse_args()
    r = train_symbol(args.symbol)
    print(json.dumps({k: v for k, v in r.items() if k != 'windows'}, indent=2))
    if r.get('windows'):
        print(f"windows: {len(r['windows'])}, avg_acc: {r['avg_accuracy']}")
