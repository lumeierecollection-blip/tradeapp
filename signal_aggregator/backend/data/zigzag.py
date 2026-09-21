"""ZigZag pivot detector for structural feature extraction."""
import pandas as pd


def zigzag(df: pd.DataFrame, threshold_pct: float = 1.0) -> pd.DataFrame:
    """
    Returns df with two added columns:
      - pivot_type: 'high' | 'low' | None
      - pivot_price: float | None
    A new pivot is marked when price reverses by threshold_pct from the last extreme.
    """
    df = df.copy()
    df['pivot_type'] = None
    df['pivot_price'] = None
    if len(df) < 2:
        return df
    last_pivot_idx = 0
    last_pivot_price = df['Close'].iloc[0]
    direction = 1
    for i in range(1, len(df)):
        price = df['Close'].iloc[i]
        change = (price - last_pivot_price) / last_pivot_price * 100
        if direction == 1 and change <= -threshold_pct:
            df.at[df.index[last_pivot_idx], 'pivot_type'] = 'high'
            df.at[df.index[last_pivot_idx], 'pivot_price'] = last_pivot_price
            last_pivot_price = price
            last_pivot_idx = i
            direction = -1
        elif direction == -1 and change >= threshold_pct:
            df.at[df.index[last_pivot_idx], 'pivot_type'] = 'low'
            df.at[df.index[last_pivot_idx], 'pivot_price'] = last_pivot_price
            last_pivot_price = price
            last_pivot_idx = i
            direction = 1
        elif (direction == 1 and price > last_pivot_price) or \
             (direction == -1 and price < last_pivot_price):
            last_pivot_price = price
            last_pivot_idx = i
    return df
