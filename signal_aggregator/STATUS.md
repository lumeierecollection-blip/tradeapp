# tradeapp Signal Engine — Status

## Current state (2026-09-21)
- ML pipeline live (LightGBM, 35 features, cross-asset)
- Walk-forward: 8 windows per combo (10y data)
- Holdout: 2023-2026 validation complete
- Survivors (passed WF + holdout): 4 combinations
  - GC=F     | ma_cross | 1d
  - USDJPY=X | ma_cross | 1d
  - ^GSPC    | ma_cross | 1d
  - ^NDX     | ma_cross | 1d

## Known limits
- 1h results untestable (Yahoo 730d limit)
- 5% survivor rate is at noise threshold
- ML model is directional, not profitability-validated
- Yahoo data 15-20 min delayed
- yfinance unofficial

## Next steps (in order)
1. Third-period validation (2021-2022) on the 4 survivors
2. Live paper trade the 4 survivors for 30 days
3. Compare live vs backtest divergence
4. Only then consider position sizing

## Do not
- Trade non-survivor signals
- Increase size before 30 days of live paper
- Assume accuracy = profitability
