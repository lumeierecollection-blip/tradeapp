# OpenCode Master Prompt — tradeapp (crypto signal app)

> Supersedes the "Part 1" prompt in `changes.txt`. That prompt was too broad (5 phases,
> ~30 new files, an in-app reinforcement-learning agent) and the half-applied result
> currently **does not compile**. This version is sequenced by risk and scoped to what
> actually moves the needle.

---

## Role & repository

You are the lead engineer upgrading an existing **Flutter (Dart) cryptocurrency signal
aggregator**. The Flutter project lives in `signal_aggregator/`. Market data comes from the
**Binance public REST API** (`signal_aggregator/lib/services/market_service.dart`), which
already returns proper OHLCV klines, 24h stats, RSI, ATR%, support/resistance and volume
ratios. Signals are produced and scored in `lib/services/validator.dart` →
`models/validated_signal.dart` (direction, entry, stop, take-profit, probability, summary).

**Build on this system. Do not rebuild it.**

---

## Non-negotiables

1. **The build stays green.** After every change, `flutter analyze` has zero errors and
   `flutter test` passes. Never leave `main` uncompilable.
2. **No fabricated market data.** No placeholder prices, random values, guessed
   volatility/volume/levels, or silent fallbacks that make a signal look valid. If data is
   missing or stale, say so and downgrade or drop the signal. A missing signal beats a fake one.
3. **Reuse the existing Binance klines.** Do not add Yahoo Finance or other historical-price
   providers — Binance `/api/v3/klines` already gives clean OHLCV for every supported symbol.
4. **Every calculation is deterministic, explainable, and unit-tested.**
5. **No new paid APIs. No automatic order execution. No API keys or secrets in the Flutter app.**
6. **Do not restructure the architecture** (no "clean architecture" migration, no importing a
   third-party UI kit). Refactor only the files you are already touching.
7. **Small, reviewable steps.** One tier = one PR. Stop and report at the end of each tier.

---

## Step 0 — Audit, then fix the broken build (do this first)

The uncommitted backtesting work is non-compiling. Read these files and fix them minimally
(or revert them and redo cleanly under Tier 1 — your call, but the build must be green before
you move on):

- `lib/services/paper_trader.dart` — imports `package:flutter/fast.dart` (does not exist);
  declares the `PaperTrader` constructor **three times**; references helpers that live on the
  engine, not the class.
- `lib/backtesting/backtest_engine.dart` — calls `event.when(...)` on a plain abstract class
  (no union type); reassigns `final _initialBalance`; malformed nested-brace parameter list in
  `runBacktest`; `candles` referenced out of scope in `_shouldOpenTrade` / `_calculateRsi`;
  `openedAt: candle.openTime` passes an `int` where `DateTime` is expected.
- `lib/backtesting/performance_metrics.dart` — uses `sqrt` without `import 'dart:math'`;
  `PaperTrade` not imported; `initialBalance + trade.pnl ?? 0` has a precedence bug.
- `lib/backtesting/data_providers/yahoo_provider.dart` — `interval.replaceFirstMinute` is not
  a real API. **Delete this file and the `data_providers/` folder** (see rule 3).
- `lib/ui/screens/backtest_screen.dart` — `YahooDataProvider` not imported; passes a nullable
  `signal` where non-null is required.

Also in Step 0, produce a short written audit: current data flow, state management
(`lib/state/app_state.dart`), where signals are generated/validated/rendered, and what
persistence exists (`lib/services/storage.dart`).

---

## Tier 1 — Critical: make the core trustworthy

### 1a. Backtesting engine (redo it properly)
- **Files:** `lib/backtesting/backtest_engine.dart`, `lib/backtesting/performance_metrics.dart`,
  `lib/backtesting/position_sizing.dart`, `lib/ui/screens/backtest_screen.dart`.
- Deterministic **bar-by-bar** loop over Binance klines for one symbol + one strategy config.
- **No look-ahead:** decisions at bar _i_ use only data up to and including bar _i_; fills
  happen at bar _i+1_ open.
- **Costs on every fill:** taker fee (default 0.10%), slippage (default 0.05%), and spread.
  Make them configurable; show gross vs. net.
- **Metrics:** trades, win rate, profit factor, expectancy, average win/loss, max drawdown
  (% and absolute), longest losing streak. Sharpe is optional and clearly labelled as
  per-trade, not annualised.
- Results screen: equity curve + the metrics table. Use `CustomPaint` or a lightweight chart
  already in `pubspec.yaml`; do not add a heavy charting dependency.
- **Tests:** feed a hand-built candle series with a known outcome and assert every metric.

### 1b. Realistic paper execution
- **File:** `lib/services/paper_trader.dart`.
- Apply the **same** fee/slippage/spread model as the backtester to `openTrade`, `closeTrade`,
  `closeAtMarket`, `checkStops`.
- Fix `closeTrade`: current exit-price selection is inconsistent. Fill stop/target at the
  stop/target price, manual closes at the passed market price, minus costs.
- Entry fills at the next observed price, not the exact displayed signal price.
- **Tests:** round-trip a trade and assert balance reflects entry cost + exit cost.

### 1c. Trade & signal journal (the substrate for Tier 2)
- **Files:** new `lib/journal/` (models + service), persisted via `lib/services/storage.dart`.
- Record **every signal shown** (symbol, timestamp, direction, entry/stop/target, probability,
  the summary/reasons) and **every paper trade** with its realized outcome and `closedBy`.
- Keep it append-only; expose queries by symbol, by date range, by probability bucket.
- **Tests:** persistence round-trip; query correctness.

---

## Tier 2 — High value: the learning layer (no ML)

### 2a. Mistake tagging
- On each closed trade, allow manual tags from a fixed taxonomy: `early-entry`, `late-entry`,
  `oversized`, `moved-stop`, `chased-pump`, `ignored-invalidation`, `traded-into-news`, `good`.
- Show recurrence counts and win rate per tag. No auto-categorisation, no RL.

### 2b. Historical performance dashboard
- Reads only from the journal (Tier 1c). Show signal accuracy over time, by symbol, and by
  probability bucket (e.g. 50–60 / 60–70 / 70+), so a degrading generator is visible.
- Replaces the ad-hoc stats currently on `paper_trader.dart`.

### 2c. Data resilience
- Add **one** free fallback price source (e.g. Coinbase or Kraken public ticker) behind the
  existing 20s cache in `market_service.dart`.
- When both sources fail or data is older than the TTL, surface an explicit **"stale data"**
  state to the UI and to the validator — stop silently reusing old snapshots as if fresh.
- **Tests:** simulate primary failure → fallback used; simulate both fail → stale state.

---

## Tier 3 — Nice to have (only after Tiers 1–2 ship)

- **Event awareness:** flag signals raised inside a high-impact window (CPI / FOMC / major
  scheduled crypto unlocks). A small static/annual list is fine; no calendar API.
- **Cloud sync conflicts:** last-write-wins by timestamp with a manual device resolver, and
  always snapshot local trade history before an incoming overwrite.
- **Red/black theme:** apply the palette from `colour.txt` via `lib/ui/theme.dart` only —
  no hardcoded colors in widgets. Cosmetic; lowest risk; can run in parallel.
- **Opportunistic modularity:** tidy separation of concerns *in files you already touch*.

---

## Explicitly out of scope

- In-app reinforcement learning / DQN / `tflite_flutter`. If adaptivity is wanted later, do
  **walk-forward parameter tuning via the backtester** (grid search), not a learned agent.
- Yahoo Finance / Alpha Vantage / any new historical-data provider.
- Clean-architecture migration or importing an external Flutter UI kit.
- New paid APIs, brokerage integrations, or live order execution.

---

## Working agreement

- Start with Step 0 and post the audit before writing feature code.
- One tier per PR; each PR: `flutter analyze` clean, `flutter test` green, and a short note on
  what changed and how you verified it.
- If a task needs a decision that changes scope, stop and ask.
