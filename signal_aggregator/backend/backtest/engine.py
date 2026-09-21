import argparse
import json
import math
import os
import random
from datetime import datetime

import numpy as np
import pandas as pd
import yfinance as yf


def compute_atr(df, period=14):
    high = df['High']
    low = df['Low']
    close = df['Close']
    tr1 = high - low
    tr2 = (high - close.shift()).abs()
    tr3 = (low - close.shift()).abs()
    tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
    return tr.rolling(period).mean()


def _execute_backtest(hist, strategy, symbol, initial_capital=10000.0):
    """Run backtest on a slice of OHLCV data. Returns (trades, equity_curve, exit_reason_counts)."""
    capital = initial_capital
    position = 0
    entry_price = 0.0
    stop = 0.0
    target = 0.0
    trades = []
    equity_curve = [initial_capital]
    exit_reason_counts = {}

    spread_pips = 1.5
    pip_size = 0.01 if 'JPY' in symbol else 0.0001
    spread_cost = spread_pips * pip_size

    atr = compute_atr(hist, period=14)

    for i in range(1, len(hist)):
        price = hist['Close'].iloc[i]
        high_i = hist['High'].iloc[i]
        low_i = hist['Low'].iloc[i]

        if position > 0:
            if low_i <= stop:
                fill_price = stop - spread_cost / 2
                capital = position * fill_price
                trades.append({'type': 'SELL', 'price': fill_price, 'equity': capital, 'exit_reason': 'stop'})
                exit_reason_counts['stop'] = exit_reason_counts.get('stop', 0) + 1
                position = 0
            elif high_i >= target:
                fill_price = target - spread_cost / 2
                capital = position * fill_price
                trades.append({'type': 'SELL', 'price': fill_price, 'equity': capital, 'exit_reason': 'target'})
                exit_reason_counts['target'] = exit_reason_counts.get('target', 0) + 1
                position = 0

        next_open = hist['Open'].iloc[i + 1] if i + 1 < len(hist) else None

        if position <= 0 and next_open is not None:
            should_buy = False

            if strategy == 'ma_cross':
                short_ma = hist['Close'].iloc[:i].rolling(5).mean().iloc[-1]
                long_ma = hist['Close'].iloc[:i].rolling(20).mean().iloc[-1]
                if not pd.isna(short_ma) and not pd.isna(long_ma) and short_ma > long_ma:
                    should_buy = True
            elif strategy == 'rsi':
                delta = hist['Close'].iloc[:i].diff()
                gain = (delta.where(delta > 0, 0)).rolling(14).mean()
                loss = (-delta.where(delta < 0, 0)).rolling(14).mean()
                rs = gain / loss
                rsi = 100 - (100 / (1 + rs))
                last_rsi = rsi.iloc[-1] if not pd.isna(rsi.iloc[-1]) else 50
                if last_rsi < 30:
                    should_buy = True

            if should_buy:
                atr_val = atr.iloc[i] if not pd.isna(atr.iloc[i]) else price * 0.01
                fill_price = next_open + spread_cost / 2
                position = capital / fill_price
                entry_price = fill_price
                stop = entry_price - 2.5 * atr_val
                target = entry_price + 3.5 * atr_val
                capital = 0.0
                trades.append({'type': 'BUY', 'price': fill_price, 'equity': position * price, 'exit_reason': None})

        portfolio_value = capital + position * price
        equity_curve.append(portfolio_value)

    if position > 0:
        final_price = hist['Close'].iloc[-1] - spread_cost / 2
        capital = position * final_price
        trades.append({'type': 'SELL', 'price': final_price, 'equity': capital, 'exit_reason': 'end_of_data'})
        exit_reason_counts['end_of_data'] = exit_reason_counts.get('end_of_data', 0) + 1
        position = 0
        equity_curve[-1] = capital

    return trades, equity_curve, exit_reason_counts


def compute_sharpe(curve, risk_free=0.0, periods_per_year=252):
    if len(curve) < 2:
        return 0.0
    returns = pd.Series(curve).pct_change().dropna()
    if returns.std() == 0:
        return 0.0
    sharpe = (returns.mean() - risk_free / periods_per_year) / returns.std() * (periods_per_year ** 0.5)
    return sharpe if np.isfinite(sharpe) else 0.0


def compute_max_drawdown(curve):
    if not curve:
        return 0.0
    peak = curve[0]
    max_dd = 0.0
    for value in curve:
        if value > peak:
            peak = value
        dd = (peak - value) / peak
        if dd > max_dd:
            max_dd = dd
    return max_dd


def compute_win_rate(trades):
    if not trades:
        return 0.0
    winning = sum(1 for t in trades if t.get('type') == 'SELL')
    return winning / len(trades)


def run_backtest(symbol, strategy, timeframe):
    random.seed(42)

    ticker = yf.Ticker(symbol)
    hist = ticker.history(period='1y', interval=timeframe if timeframe in ('1d', '1h', '5m') else '1d')
    if hist.empty:
        hist = pd.DataFrame({'Open': [1.0], 'High': [1.0], 'Low': [1.0], 'Close': [1.0], 'Volume': [0]})

    trades, equity_curve, exit_reason_counts = _execute_backtest(hist, strategy, symbol)

    final_equity = equity_curve[-1]
    total_return = (final_equity - 10000.0) / 10000.0 * 100
    sharpe_ratio = compute_sharpe(equity_curve)
    max_drawdown = compute_max_drawdown(equity_curve)
    win_rate = compute_win_rate(trades)

    results = {
        'timestamp': datetime.now().strftime('%Y-%m-%dT%H:%M:%SZ'),
        'symbol': symbol,
        'strategy': strategy,
        'timeframe': timeframe,
        'sharpe_ratio': round(sharpe_ratio, 2) if np.isfinite(sharpe_ratio) else 0.0,
        'max_drawdown': round(max_drawdown * 100, 2),
        'win_rate': round(win_rate * 100, 2),
        'total_return': round(total_return, 2),
        'total_trades': len(trades),
        'final_equity': round(final_equity, 2),
        'equity_curve': equity_curve,
        'exit_reason_counts': exit_reason_counts,
    }

    os.makedirs(os.path.dirname('data/backtest/results.json'), exist_ok=True)
    with open('data/backtest/results.json', 'w') as f:
        json.dump(results, f, indent=2)

    return results


def _fetch_history(symbol, timeframe):
    ticker = yf.Ticker(symbol)
    hist = ticker.history(period='1y', interval=timeframe if timeframe in ('1d', '1h', '5m') else '1d')
    if hist.empty:
        return pd.DataFrame()
    return hist


def _windows_from_hist(hist, train_months, test_months):
    """Split hist into consecutive (train, test) windows using bar counts.

    For daily: 1 month ≈ 21 bars. For hourly: 1 month ≈ 21*6 = 126 bars.
    Approximate from the index span to be timeframe-agnostic.
    """
    total_bars = len(hist)
    if total_bars < 30:
        return []

    days_span = (hist.index[-1] - hist.index[0]).days
    if days_span <= 0:
        return []
    bars_per_day = total_bars / days_span
    train_bars = int(train_months * 30 * bars_per_day)
    test_bars = int(test_months * 30 * bars_per_day)

    if train_bars < 20 or test_bars < 5:
        return []

    windows = []
    start = 0
    while start + train_bars + test_bars <= total_bars:
        train_slice = hist.iloc[start:start + train_bars]
        test_start = start + train_bars
        test_end = min(test_start + test_bars, total_bars)
        test_slice = hist.iloc[test_start:test_end]
        windows.append((train_slice, test_slice))
        start = test_end

    return windows


def run_walk_forward(symbol, strategy, timeframe, train_months=6, test_months=1):
    hist = _fetch_history(symbol, timeframe)
    if hist.empty:
        print(f'No data for {symbol}')
        return None

    windows = _windows_from_hist(hist, train_months, test_months)
    if not windows:
        print(f'Not enough data for walk-forward ({len(hist)} bars, need ~{train_months + test_months} months)')
        return None

    print(f'Walk-forward: {len(windows)} windows, train={train_months}mo, test={test_months}mo')

    window_results = []
    for idx, (train, test) in enumerate(windows):
        trades, equity_curve, _ = _execute_backtest(test, strategy, symbol)
        test_return = (equity_curve[-1] - 10000.0) / 10000.0 * 100
        test_sharpe = compute_sharpe(equity_curve)

        window_results.append({
            'train_start': str(train.index[0]),
            'train_end': str(train.index[-1]),
            'test_start': str(test.index[0]),
            'test_end': str(test.index[-1]),
            'test_return': round(test_return, 2),
            'test_sharpe': round(test_sharpe, 2) if np.isfinite(test_sharpe) else 0.0,
            'test_trades': len(trades),
        })

    sharpes = [w['test_sharpe'] for w in window_results]
    avg_sharpe = float(np.mean(sharpes)) if sharpes else 0.0
    std_sharpe = float(np.std(sharpes, ddof=1)) if len(sharpes) > 1 else 0.0
    pct_positive = sum(1 for s in sharpes if s > 0) / len(sharpes) * 100 if sharpes else 0.0

    output = {
        'symbol': symbol,
        'strategy': strategy,
        'timeframe': timeframe,
        'train_months': train_months,
        'test_months': test_months,
        'windows': window_results,
        'avg_test_sharpe': round(avg_sharpe, 2),
        'std_test_sharpe': round(std_sharpe, 2),
        'pct_windows_positive': round(pct_positive, 1),
    }

    os.makedirs('data/backtest', exist_ok=True)
    with open('data/backtest/walkforward.json', 'w') as f:
        json.dump(output, f, indent=2)

    for w in window_results:
        print(f"  {w['test_start'][:10]} -> {w['test_end'][:10]}: "
              f"sharpe={w['test_sharpe']:>6.2f}  ret={w['test_return']:>6.2f}%  trades={w['test_trades']}")

    print(f'  Avg test Sharpe: {avg_sharpe:.2f}')
    print(f'  Std test Sharpe: {std_sharpe:.2f}')
    print(f'  % positive windows: {pct_positive:.1f}%')

    return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Run backtest')
    parser.add_argument('--symbol', default='EURUSD=X')
    parser.add_argument('--strategy', default='ma_cross')
    parser.add_argument('--timeframe', default='1h')
    parser.add_argument('--walk-forward', action='store_true')
    parser.add_argument('--wf-train-months', type=int, default=6)
    parser.add_argument('--wf-test-months', type=int, default=1)
    args = parser.parse_args()

    if args.walk_forward:
        run_walk_forward(args.symbol, args.strategy, args.timeframe,
                         args.wf_train_months, args.wf_test_months)
    else:
        run_backtest(args.symbol, args.strategy, args.timeframe)
