"""Simple regime classifier: trending vs ranging vs volatile.
Uses volatility percentile + trend strength. No HMM for v1."""
import pandas as pd


def classify_regime(features: pd.DataFrame) -> pd.Series:
    """
    Returns a Series of regime labels:
      'trend'  = low vol + strong trend
      'range'  = low vol + weak trend
      'vol'    = high vol
    """
    vol_pct = features['vol_percentile']
    trend = features['trend_strength'].abs()

    regime = pd.Series('range', index=features.index)
    regime[trend > 1.0] = 'trend'
    regime[vol_pct > 0.75] = 'vol'
    return regime
