import argparse
import json
import os
import random
from datetime import datetime

import numpy as np
import pandas as pd
import yfinance as yf


def compute_atr(df, period=14):
    """Compute Average True Range as a pandas Series."""
    high = df['High']
    low = df['Low']
    close = df['Close']
    tr1 = high - low
    tr2 = (high - close.shift()).abs()
    tr3 = (low - close.shift()).abs()
    tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
    return tr.rolling(period).mean()


def run_backtest(symbol, strategy, timeframe):
    random.seed(42)

    ticker = yf.Ticker(symbol)
    hist = ticker.history(period='1y', interval=timeframe if timeframe in ('1d', '1h', '5m') else '1d')
    if hist.empty:
        hist = pd.DataFrame({'Open': [1.0], 'High': [1.0], 'Low': [1.0], 'Close': [1.0], 'Volume': [0]})

    initial_capital = 10000.0
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

        # Check stops/targets on open position
        if position > 0:
            if low_i <= stop:
                fill_price = stop - spread_cost / 2
                capital = position * fill_price
                pnl = (fill_price - entry_price) * position
                trades.append({'type': 'SELL', 'price': fill_price, 'equity': capital, 'exit_reason': 'stop'})
                exit_reason_counts['stop'] = exit_reason_counts.get('stop', 0) + 1
                position = 0
            elif high_i >= target:
                fill_price = target - spread_cost / 2
                capital = position * fill_price
                pnl = (fill_price - entry_price) * position
                trades.append({'type': 'SELL', 'price': fill_price, 'equity': capital, 'exit_reason': 'target'})
                exit_reason_counts['target'] = exit_reason_counts.get('target', 0) + 1
                position = 0

        # Entry signals — fill at next bar's open
        if i + 1 < len(hist):
            next_open = hist['Open'].iloc[i + 1]
        else:
            next_open = None

        if position <= 0 and next_open is not None:
            should_buy = False
            should_sell_signal = False

            if strategy == 'ma_cross':
                short_ma = hist['Close'].iloc[:i].rolling(5).mean().iloc[-1]
                long_ma = hist['Close'].iloc[:i].rolling(20).mean().iloc[-1]
                if short_ma > long_ma:
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
            elif strategy == 'vwap':
                typical = (hist['High'].iloc[:i] + hist['Low'].iloc[:i] + hist['Close'].iloc[:i]) / 3
                vwap = (typical * hist['Volume'].iloc[:i]).cumsum() / hist['Volume'].iloc[:i].cumsum()
                if price < vwap.iloc[-1] * 0.99:
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

    # Close any remaining position at end-of-data
    if position > 0:
        final_price = hist['Close'].iloc[-1] - spread_cost / 2
        capital = position * final_price
        trades.append({'type': 'SELL', 'price': final_price, 'equity': capital, 'exit_reason': 'end_of_data'})
        exit_reason_counts['end_of_data'] = exit_reason_counts.get('end_of_data', 0) + 1
        position = 0
        equity_curve[-1] = capital

    final_equity = equity_curve[-1]
    total_return = (final_equity - initial_capital) / initial_capital * 100

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
    winning_trades = sum(1 for t in trades if t.get('type') == 'SELL')
    return winning_trades / len(trades)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Run backtest')
    parser.add_argument('--symbol', default='EURUSD=X')
    parser.add_argument('--strategy', default='ma_cross')
    parser.add_argument('--timeframe', default='1h')
    args = parser.parse_args()
    run_backtest(args.symbol, args.strategy, args.timeframe)
