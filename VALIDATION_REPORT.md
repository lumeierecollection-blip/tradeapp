# TradeApp — Survivor Validation Report

Goal: test whether the 4 holdout survivors (GC=F, USDJPY=X, ^GSPC, ^NDX) are a structural edge or ticker-specific luck.

Scope: `ma_cross 1d` only. No strategy logic changed.

## 1. Sibling-asset holdout test

Train 2016-2022, test 2023-2026 (same split as the original holdout).
Pass criteria: `sharpe > 0.5 AND trades >= 5`.

| Survivor  | Sibling    | Sharpe | Trades | Win% | Pass? |
|-----------|------------|--------|--------|------|-------|
| GC=F      | SI=F       | 0.58   | 118    | 50   | YES   |
| GC=F      | PL=F       | 0.63   | 116    | 50   | YES   |
| USDJPY=X  | USDCHF=X   | -0.09  | 52     | 50   | NO    |
| USDJPY=X  | EURJPY=X   | 0.54   | 46     | 50   | YES   |
| USDJPY=X  | GBPJPY=X   | 0.92   | 46     | 50   | YES   |
| ^GSPC     | ^NDX       | 0.84   | 74     | 50   | YES   |
| ^GSPC     | ^DJI       | 0.83   | 64     | 50   | YES   |
| ^GSPC     | ^RUT       | 0.55   | 64     | 50   | YES   |
| ^NDX      | ^GSPC      | 0.85   | 76     | 50   | YES   |
| ^NDX      | ^RUT       | 0.55   | 64     | 50   | YES   |
| ^NDX      | ^DJI       | 0.83   | 64     | 50   | YES   |

```
Total sibling tests: 11
Passed: 10
Pass rate: 90.9%
Most-consistent class: precious metals (100%) and indices (100%); JPY crosses 67%
```

## 2. Third-period validation (2021-2022)

Train 2016-2020, test 2021-01-01 .. 2023-01-01.

| Symbol   | Sharpe | Trades | Pass? |
|----------|--------|--------|-------|
| GC=F     | -0.09  | 32     | FAIL  |
| USDJPY=X | 1.70   | 32     | PASS  |
| ^GSPC    | -0.22  | 34     | FAIL  |
| ^NDX     | -0.35  | 36     | FAIL  |

```
GC=F:     FAIL
USDJPY=X: PASS
^GSPC:    FAIL
^NDX:     FAIL
```

## 3. Combined verdict

Verdict rules:
- **confirmed**: holdout23-26 pass AND holdout21-22 pass AND >=60% of siblings pass
- **partial**: passed 2 of 3 tests
- **failed**: passed 0-1 tests

| Symbol   | WF     | HO23-26 | HO21-22 | Siblings% | Verdict |
|----------|--------|---------|---------|-----------|---------|
| GC=F     | 0.85   | 1.00    | -0.09   | 100%      | partial |
| USDJPY=X | 0.75   | 0.63    | 1.70    | 67%       | confirmed |
| ^GSPC    | 1.38   | 0.81    | -0.22   | 100%      | partial |
| ^NDX     | 0.66   | 0.80    | -0.35   | 100%      | partial |

```
Confirmed: 1
Partial:   3
Failed:    0
```

## Interpretation

The edge generalizes across asset classes (10/11 siblings pass), so it is not
ticker-specific luck. But only USDJPY=X survived an independent 2021-2022
regime — GC, ^GSPC and ^NDX flopped in the pre-2023 period, so their big
2023-2026 gains were regime-specific (sustained post-2022 trends), not
structural. Real but modest: a durable long-cross tilt with strongest support
on FX/indices in trending regimes, weakest in choppy/mean-reverting years.

## FINAL REPORT

```
===== VALIDATION SUMMARY =====

Sibling test:
  Total siblings tested: 11
  Passed: 10 (90.9%)
  Most-consistent class: precious metals & indices (100%); JPY crosses 67%

Third-period test (2021-2022):
  GC=F:     FAIL
  USDJPY=X: PASS
  ^GSPC:    FAIL
  ^NDX:     FAIL

Combined verdict:
  Confirmed: 1
  Partial:   3
  Failed:    0

Interpretation:
  The edge generalizes across sibling assets (10/11 pass), so it is not
  ticker-specific luck. But only USDJPY=X survived the independent 2021-2022
  regime; GC, ^GSPC and ^NDX failed it, so their 2023-2026 gains were
  regime-specific (post-2022 sustained trends), not structural. The edge is
  real but partial — strongest as a trend-following tilt on FX/indices,
  weakest in choppy/mean-reverting years.
=====
```

## Artifacts

- `data/backtest/sibling_check.json`
- `data/backtest/holdout_21_22.json`
- `data/backtest/validation_summary.json`
- Scripts: `signal_aggregator/backend/backtest/run_sibling_check.py`,
  `run_third_period.py`, `validation_summary.py` (shared `validation_common.py`)

Generated 2026-09-22 from commit `7ea9e89`.

---

# Addendum — Regime-Conditioned Backtest

Goal: test whether `--regime-filter` (only open trades when `classify_regime`
returns `'trend'`) rescues the 3 partial survivors (GC=F, ^GSPC, ^NDX).

Scope: `ma_cross 1d` only. No strategy logic changed. Features replicate
`backend/ml/features.py`: `vol_20 = ret_1.rolling(20).std()`,
`vol_percentile = vol_20.rolling(100).rank(pct=True)`,
`trend_strength = (close - close.rolling(50).mean()) / close.rolling(50).std()`
(all trailing). Walk-forward windows use the train slice as feature warm-up so
the 50/100-bar indicators can initialize; holdouts use the post-holdout slice.

## 4. Verification (`GC=F ma_cross 1d`)

| Run                | Exit | Trades |
|--------------------|------|--------|
| no filter          | 0    | 212    |
| `--regime-filter`  | 0    | 172    |

Trade count drops with the filter; both exit 0.

## 5. Regime-filtered validation vs no-filter baselines

Pass criterion: `sharpe > 0.5` (holdouts also `trades >= 5`).

| Symbol   | Test     | NoFilter | WithFilter | Delta  |
|----------|----------|----------|------------|--------|
| GC=F     | WF       | 0.85     | 1.24       | +0.39  |
| GC=F     | HO23-26  | 1.00     | 0.80       | -0.20  |
| GC=F     | HO21-22  | -0.09    | -0.07      | +0.02  |
| USDJPY=X | WF       | 0.75     | 0.46       | -0.29  |
| USDJPY=X | HO23-26  | 0.63     | 0.04       | -0.59  |
| USDJPY=X | HO21-22  | 1.70     | 1.34       | -0.36  |
| ^GSPC    | WF       | 1.38     | 1.32       | -0.06  |
| ^GSPC    | HO23-26  | 0.81     | 0.90       | +0.09  |
| ^GSPC    | HO21-22  | -0.22   | 0.21       | +0.43  |
| ^NDX     | WF       | 0.66     | 1.29       | +0.63  |
| ^NDX     | HO23-26  | 0.80     | 0.58       | -0.22  |
| ^NDX     | HO21-22  | -0.35   | 0.86       | +1.21  |

## 6. Verdicts

Rules: confirmed = all 3 pass; improved = 1-2 fail->pass; unchanged = same
pattern; worsened = any pass->fail.

| Symbol   | Old pattern      | New pattern      | Verdict   |
|----------|------------------|------------------|-----------|
| ^NDX     | WF pass, HO23 pass, HO21 fail | pass, pass, pass | **confirmed** |
| GC=F     | pass, pass, fail | pass, pass, fail | unchanged |
| ^GSPC    | pass, pass, fail | pass, pass, fail | unchanged |
| USDJPY=X | pass, pass, pass | fail, fail, pass | worsened |

```
Confirmed: 1 (^NDX)
Improved:  0
Unchanged: 2 (GC=F, ^GSPC)
Worsened:  1 (USDJPY=X)
TRADEABLE CANDIDATES (3/3 with filter): ['^NDX']
```

## Interpretation

The regime filter did NOT rescue the 3 partial survivors. GC=F and ^GSPC keep
their pattern (WF & HO23 pass, HO21 fail) — their 2021-2022 underperformance
persists even trend-gated, so it is not a trend-chasing artifact. It PUSHED
USDJPY=X from a confirmed edge to fail on both WF (0.46) and HO23-26 (0.04):
its mark-to-market edge lives in range/vol regimes, not trend regimes. The
one genuine rescue is ^NDX, whose HO21-22 flips from -0.35 to 0.86, and with
WF (1.29) and HO23-26 (0.58) still passing it becomes the only symbol that
passes all three tests with the filter on.

## Artifacts

- `data/backtest/regime_validation.json`
- Script: `signal_aggregator/backend/backtest/run_regime_validation.py`
- `engine.py --regime-filter` (also threaded through walk-forward/holdout)

Generated 2026-09-22.