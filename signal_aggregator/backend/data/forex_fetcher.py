import json
import os
from datetime import datetime

import pandas as pd
import yfinance as yf

from zigzag import zigzag


def fetch_forex_ohlcv(symbol, interval='1h', period='7d'):
    """Fetch OHLCV data from Yahoo Finance for a forex symbol."""
    data = yf.download(symbol, interval=interval, period=period)
    if data.empty:
        return pd.DataFrame()
    df = data[['Open', 'High', 'Low', 'Close', 'Volume']].copy()
    df.reset_index(inplace=True)
    df['Symbol'] = symbol
    return df


def main():
    symbols = ['EURUSD=X', 'GBPUSD=X', 'USDJPY=X', 'GC=F', 'AUDUSD=X']
    os.makedirs('data/raw', exist_ok=True)

    for symbol in symbols:
        try:
            df = fetch_forex_ohlcv(symbol)
            if df.empty:
                print(f'No data for {symbol}')
                continue
            df = zigzag(df)
            records = df.to_dict(orient='records')
            for r in records:
                for k, v in r.items():
                    if hasattr(v, 'item'):
                        r[k] = v.item()
                    elif hasattr(v, 'isoformat'):
                        r[k] = v.isoformat()
            out_path = f'data/raw/{symbol.replace("=", "_")}.json'
            with open(out_path, 'w') as f:
                json.dump(records, f, indent=2)
            print(f'Saved {len(records)} bars for {symbol} -> {out_path}')
        except Exception as e:
            print(f'Error fetching {symbol}: {e}')


if __name__ == '__main__':
    main()
