"""Feature engineering — ~40 features per bar from OHLCV + cross-asset."""
import numpy as np
import pandas as pd


def build_features(ohlcv: pd.DataFrame, cross: pd.DataFrame) -> pd.DataFrame:
    """
    ohlcv: DataFrame with columns open, high, low, close, volume, index=datetime
    cross: DataFrame with columns vix, dxy, tnx, gold, oil, spx (daily)
    Returns: DataFrame with engineered features, same index as ohlcv
    """
    df = ohlcv.copy()
    c = df['close']

    # --- Returns ---
    df['ret_1']  = c.pct_change(1)
    df['ret_5']  = c.pct_change(5)
    df['ret_10'] = c.pct_change(10)
    df['ret_20'] = c.pct_change(20)

    # --- Volatility ---
    df['vol_10'] = df['ret_1'].rolling(10).std()
    df['vol_20'] = df['ret_1'].rolling(20).std()
    df['vol_ratio'] = df['vol_10'] / df['vol_20'].replace(0, np.nan)

    # --- Moving averages & distance ---
    for p in [10, 20, 50]:
        df[f'sma_{p}'] = c.rolling(p).mean()
        df[f'dist_sma_{p}'] = (c - df[f'sma_{p}']) / df[f'sma_{p}']

    # --- RSI (14) ---
    delta = c.diff()
    gain = delta.where(delta > 0, 0).rolling(14).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(14).mean()
    rs = gain / loss.replace(0, np.nan)
    df['rsi_14'] = 100 - (100 / (1 + rs))

    # --- Bollinger %B ---
    bb_mid = c.rolling(20).mean()
    bb_std = c.rolling(20).std()
    df['bb_pctb'] = (c - (bb_mid - 2*bb_std)) / ((bb_mid + 2*bb_std) - (bb_mid - 2*bb_std))

    # --- ATR normalized ---
    h_l = df['high'] - df['low']
    h_c = (df['high'] - c.shift()).abs()
    l_c = (df['low'] - c.shift()).abs()
    tr = pd.concat([h_l, h_c, l_c], axis=1).max(axis=1)
    df['atr_pct'] = tr.rolling(14).mean() / c

    # --- Range / body ---
    df['range_pct'] = (df['high'] - df['low']) / c
    df['body_pct']  = (df['close'] - df['open']) / c

    # --- Volume z-score ---
    if 'volume' in df.columns and df['volume'].sum() > 0:
        v = df['volume']
        df['vol_z'] = (v - v.rolling(20).mean()) / v.rolling(20).std().replace(0, np.nan)
    else:
        df['vol_z'] = 0.0

    # --- Cross-asset features (align on date) ---
    if not cross.empty:
        cross = cross.reindex(df.index, method='ffill')
        for col in cross.columns:
            df[f'x_{col}_ret_1'] = cross[col].pct_change(1)
            df[f'x_{col}_ret_5'] = cross[col].pct_change(5)
        # Correlations with vix/dxy on rolling 20
        if 'vix' in cross.columns:
            df['corr_vix'] = c.pct_change().rolling(20).corr(cross['vix'].pct_change())
        if 'dxy' in cross.columns:
            df['corr_dxy'] = c.pct_change().rolling(20).corr(cross['dxy'].pct_change())

    # --- Regime features ---
    df['vol_percentile'] = df['vol_20'].rolling(100).rank(pct=True)
    df['trend_strength'] = (c - c.rolling(50).mean()) / c.rolling(50).std()

    return df.dropna()


def make_labels(features: pd.DataFrame, horizon: int = 1, threshold: float = 0.001):
    """
    Label each row by future return over `horizon` bars.
    1 = BUY (future return > +threshold)
    0 = HOLD (in between)
    -1 = SELL (future return < -threshold)
    """
    future_ret = features['close'].shift(-horizon) / features['close'] - 1
    labels = pd.Series(0, index=features.index)
    labels[future_ret >  threshold] = 1
    labels[future_ret < -threshold] = -1
    return labels
