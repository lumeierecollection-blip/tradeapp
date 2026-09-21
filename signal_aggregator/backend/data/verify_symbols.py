import yfinance as yf

SYMBOLS = [
    'EURUSD=X', 'GBPUSD=X', 'USDJPY=X', 'AUDUSD=X',
    'GBPJPY=X', 'EURJPY=X', 'AUDJPY=X', 'NZDUSD=X', 'USDCAD=X',
    'GC=F', 'SI=F', 'CL=F', 'NG=F',
    'BTC-USD', 'ETH-USD', 'SOL-USD', 'BNB-USD',
    '^GSPC', '^NDX', '^RUT',
]

for s in SYMBOLS:
    try:
        df = yf.download(s, period='5d', interval='1d', progress=False)
        if df.empty:
            print(f"FAIL {s}: 0 bars")
        else:
            close = df['Close'].iloc[-1]
            if hasattr(close, 'item'):
                close = close.item()
            print(f"OK   {s}: {len(df)} bars, last close = {close:.4f}")
    except Exception as e:
        print(f"FAIL {s}: {e}")
