import json
import sys
from pathlib import Path

import pandas as pd
import yfinance as yf

from zigzag import zigzag

# Resolved from this file, not the CWD: signal_aggregator/data/raw/
RAW_DIR = Path(__file__).resolve().parents[2] / 'data' / 'raw'


def fetch_forex_ohlcv(symbol, interval='1h', period='7d'):
    """Fetch OHLCV data from Yahoo Finance for a forex symbol."""
    data = yf.download(symbol, interval=interval, period=period, progress=False)
    if data.empty:
        return pd.DataFrame()
    if isinstance(data.columns, pd.MultiIndex):  # newer yfinance: (field, ticker)
        data.columns = data.columns.get_level_values(0)
    df = data[['Open', 'High', 'Low', 'Close', 'Volume']].copy()
    df.reset_index(inplace=True)
    df['Symbol'] = symbol
    return df


def main():
    symbols = ['EURUSD=X', 'GBPUSD=X', 'USDJPY=X', 'GC=F', 'AUDUSD=X']
    RAW_DIR.mkdir(parents=True, exist_ok=True)

    failures = []
    for symbol in symbols:
        try:
            df = fetch_forex_ohlcv(symbol)
            if df.empty:
                print(f'FAIL {symbol}: no data returned', file=sys.stderr)
                failures.append(symbol)
                continue
            df = zigzag(df)
            records = df.to_dict(orient='records')
            for r in records:
                for k, v in r.items():
                    if hasattr(v, 'item'):
                        r[k] = v.item()
                    elif hasattr(v, 'isoformat'):
                        r[k] = v.isoformat()
            out_path = RAW_DIR / f'{symbol.replace("=", "_")}.json'
            with open(out_path, 'w') as f:
                json.dump(records, f, indent=2)
            print(f'OK {symbol}: {len(records)} bars saved to {out_path}')
        except Exception as e:
            print(f'FAIL {symbol}: {type(e).__name__}: {e}', file=sys.stderr)
            failures.append(symbol)
            continue

    if failures:
        print(f'\n{len(failures)} symbols failed: {failures}', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
