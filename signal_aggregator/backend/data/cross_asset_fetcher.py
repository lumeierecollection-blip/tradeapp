"""Fetch cross-asset reference data from Yahoo Finance.
All series are daily closes. Cached in memory per run."""
import yfinance as yf
import pandas as pd

CROSS_ASSETS = {
    'vix':    '^VIX',
    'dxy':    'DX-Y.NYB',
    'tnx':    '^TNX',
    'gold':   'GC=F',
    'oil':    'CL=F',
    'spx':    '^GSPC',
}


def fetch_cross_asset(period='2y', interval='1d'):
    """Return DataFrame indexed by date, columns = asset names."""
    frames = {}
    for name, ticker in CROSS_ASSETS.items():
        try:
            df = yf.download(ticker, period=period, interval=interval,
                             progress=False, auto_adjust=True)
            if df.empty:
                continue
            if isinstance(df.columns, pd.MultiIndex):
                df.columns = df.columns.get_level_values(0)
            frames[name] = df['Close']
        except Exception as e:
            print(f"[cross_asset] {name} ({ticker}) failed: {e}")
    if not frames:
        return pd.DataFrame()
    combined = pd.concat(frames, axis=1)
    combined.columns = list(frames.keys())
    combined = combined.ffill().dropna(how='all')
    return combined
