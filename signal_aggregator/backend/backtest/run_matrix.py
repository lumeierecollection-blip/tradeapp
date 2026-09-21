"""Run engine.py across a symbol × strategy × timeframe matrix.
Aggregates results into a single summary JSON for review."""
import json
import os
import subprocess
import sys
from datetime import datetime

SYMBOLS = [
    'EURUSD=X', 'GBPUSD=X', 'USDJPY=X', 'AUDUSD=X',
    'GBPJPY=X', 'EURJPY=X', 'AUDJPY=X', 'NZDUSD=X', 'USDCAD=X',
    'GC=F', 'SI=F', 'CL=F', 'NG=F',
    'BTC-USD', 'ETH-USD', 'SOL-USD', 'BNB-USD',
    '^GSPC', '^NDX', '^RUT',
]
STRATEGIES = ['ma_cross', 'rsi']
TIMEFRAMES = ['1h', '1d']
OUTPUT = 'signal_aggregator/data/backtest/matrix.json'

def main():
    results = []
    failures = []
    for symbol in SYMBOLS:
        for strategy in STRATEGIES:
            for tf in TIMEFRAMES:
                key = f"{symbol}|{strategy}|{tf}"
                try:
                    r = subprocess.run(
                        [sys.executable, 'signal_aggregator/backend/backtest/engine.py',
                         '--symbol', symbol, '--strategy', strategy, '--timeframe', tf],
                        capture_output=True, text=True, timeout=120
                    )
                    if r.returncode != 0:
                        failures.append({'key': key, 'error': r.stderr[-400:]})
                        continue
                    with open('data/backtest/results.json') as f:
                        single = json.load(f)
                    results.append({
                        'symbol': symbol, 'strategy': strategy, 'timeframe': tf,
                        'sharpe': single.get('sharpe_ratio', 0),
                        'max_dd': single.get('max_drawdown', 0),
                        'win_rate': single.get('win_rate', 0),
                        'total_return': single.get('total_return', 0),
                        'trades': single.get('total_trades', 0),
                    })
                    print(f"OK  {key}: sharpe={single.get('sharpe_ratio')} trades={single.get('total_trades')}")
                except subprocess.TimeoutExpired:
                    failures.append({'key': key, 'error': 'timeout'})
                except Exception as e:
                    failures.append({'key': key, 'error': str(e)[:200]})

    matrix = {
        'generated_at': datetime.now(datetime.UTC).isoformat(),
        'results': results,
        'failures': failures,
    }
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, 'w') as f:
        json.dump(matrix, f, indent=2)

    # Print a compact table
    print("\n=== SUMMARY ===")
    print(f"{'symbol':<12} {'strategy':<14} {'tf':<4} {'sharpe':>7} {'dd%':>6} {'win%':>6} {'ret%':>7} {'trades':>7}")
    for r in results:
        print(f"{r['symbol']:<12} {r['strategy']:<14} {r['timeframe']:<4} "
              f"{r['sharpe']:>7.2f} {r['max_dd']:>6.1f} {r['win_rate']:>6.1f} "
              f"{r['total_return']:>7.2f} {r['trades']:>7}")
    print(f"\nFailures: {len(failures)}")
    for f_item in failures:
        print(f"  {f_item['key']}: {f_item['error'][:100]}")

if __name__ == '__main__':
    main()
