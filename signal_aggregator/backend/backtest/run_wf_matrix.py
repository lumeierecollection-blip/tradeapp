"""Run walk-forward validation across all symbol × strategy × timeframe combos."""
import json
import os
import subprocess
import sys
from datetime import datetime, UTC

SYMBOLS = [
    'EURUSD=X', 'GBPUSD=X', 'USDJPY=X', 'AUDUSD=X',
    'GBPJPY=X', 'EURJPY=X', 'AUDJPY=X', 'NZDUSD=X', 'USDCAD=X',
    'GC=F', 'SI=F', 'CL=F', 'NG=F',
    'BTC-USD', 'ETH-USD', 'SOL-USD', 'BNB-USD',
    '^GSPC', '^NDX', '^RUT',
]
STRATEGIES = ['ma_cross', 'rsi']
TIMEFRAMES = ['1h', '1d']
OUTPUT = 'data/backtest/wf_matrix.json'
WF_TRAIN = 3
WF_TEST = 2


def main():
    rows = []
    total = len(SYMBOLS) * len(STRATEGIES) * len(TIMEFRAMES)
    done = 0

    for s in SYMBOLS:
        for st in STRATEGIES:
            for tf in TIMEFRAMES:
                done += 1
                key = f'{s}|{st}|{tf}'
                print(f'[{done}/{total}] {key} ...', end=' ', flush=True)
                try:
                    r = subprocess.run(
                        [sys.executable, 'signal_aggregator/backend/backtest/engine.py',
                         '--symbol', s, '--strategy', st, '--timeframe', tf,
                         '--walk-forward', '--wf-train-months', str(WF_TRAIN),
                         '--wf-test-months', str(WF_TEST)],
                        capture_output=True, text=True, timeout=180)
                    if r.returncode != 0:
                        err = r.stderr[-300:] if r.stderr else 'unknown error'
                        rows.append({'symbol': s, 'strategy': st, 'tf': tf, 'error': err})
                        print(f'FAIL: {err[:80]}')
                        continue
                    wf_path = 'data/backtest/walkforward.json'
                    with open(wf_path) as f:
                        wf = json.load(f)
                    row = {
                        'symbol': s, 'strategy': st, 'tf': tf,
                        'avg_oos_sharpe': wf.get('avg_test_sharpe', 0),
                        'std_oos_sharpe': wf.get('std_test_sharpe', 0),
                        'pct_positive': wf.get('pct_windows_positive', 0),
                        'windows': len(wf.get('windows', [])),
                        'per_window': wf.get('windows', []),
                    }
                    rows.append(row)
                    print(f"avg_sharpe={row['avg_oos_sharpe']:>6.2f}  "
                          f"pos={row['pct_positive']:>5.1f}%  "
                          f"win={row['windows']}")
                except subprocess.TimeoutExpired:
                    rows.append({'symbol': s, 'strategy': st, 'tf': tf, 'error': 'timeout'})
                    print('TIMEOUT')
                except Exception as e:
                    rows.append({'symbol': s, 'strategy': st, 'tf': tf, 'error': str(e)[:200]})
                    print(f'ERROR: {e}')

    # Filter out errors for stats
    valid = [r for r in rows if 'error' not in r]
    errors = [r for r in rows if 'error' in r]

    # Survivors: avg_sharpe > 0.5 AND pct_positive >= 50%
    survivors = [r for r in valid
                 if r.get('pct_positive', 0) >= 50
                 and r.get('avg_oos_sharpe', 0) > 0.5]

    # Medians
    import statistics
    med_sharpe = statistics.median([r['avg_oos_sharpe'] for r in valid]) if valid else 0
    med_pos = statistics.median([r['pct_positive'] for r in valid]) if valid else 0

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, 'w') as f:
        json.dump({
            'generated_at': datetime.now(UTC).isoformat(),
            'config': {'train_months': WF_TRAIN, 'test_months': WF_TEST},
            'rows': rows,
        }, f, indent=2)

    print(f"\n{'='*60}")
    print(f"  WALK-FORWARD MATRIX REPORT")
    print(f"  Config: {WF_TRAIN}mo train / {WF_TEST}mo test")
    print(f"{'='*60}")
    print(f"  Total combos:       {len(rows)}")
    print(f"  Valid:              {len(valid)}")
    print(f"  Errors:             {len(errors)}")
    print(f"  Surviving:          {len(survivors)}  (avg_sharpe>0.5 AND pos>=50%)")
    print(f"  Median OOS Sharpe:  {med_sharpe:.2f}")
    print(f"  Median % positive:  {med_pos:.1f}%")
    print()

    if survivors:
        print("  SURVIVORS:")
        for r in survivors:
            print(f"    {r['symbol']:<12} {r['strategy']:<10} {r['tf']:<4} "
                  f"avg_sharpe={r['avg_oos_sharpe']:>6.2f}  "
                  f"std={r['std_oos_sharpe']:>5.2f}  "
                  f"pos={r['pct_positive']:>5.1f}%  "
                  f"windows={r['windows']}")
    else:
        print("  NO SURVIVORS. Current strategy set has no demonstrable edge.")

    print()
    print("  FULL TABLE:")
    print(f"  {'symbol':<12} {'strategy':<10} {'tf':<4} {'avg_sharpe':>10} {'std':>6} {'pos%':>6} {'win':>4}")
    print(f"  {'-'*56}")
    for r in valid:
        marker = ' *' if r in survivors else ''
        print(f"  {r['symbol']:<12} {r['strategy']:<10} {r['tf']:<4} "
              f"{r['avg_oos_sharpe']:>10.2f} {r['std_oos_sharpe']:>6.2f} "
              f"{r['pct_positive']:>5.1f}% {r['windows']:>4}{marker}")

    if errors:
        print(f"\n  ERRORS:")
        for r in errors:
            print(f"    {r['symbol']} {r['strategy']} {r['tf']}: {r['error'][:80]}")

    print(f"{'='*60}")


if __name__ == '__main__':
    main()
