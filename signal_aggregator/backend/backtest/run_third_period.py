"""Task 2 — Third-period validation (2021-2022).

Run holdout on the 4 survivors with ma_cross 1d:
train 2016-2020, test 2021-01-01 .. 2023-01-01.
Writes data/backtest/holdout_21_22.json.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validation_common as vc


def main():
    rows = []
    for symbol in vc.SURVIVORS:
        res = vc.trigger_holdout(symbol, vc.HO_2021_START, vc.HO_2021_END)
        if 'error' in res:
            rows.append({'symbol': symbol, 'error': res['error']})
            print(f"  {symbol:<12} ERROR: {res['error'][:80]}")
            continue
        row = {
            'symbol': symbol,
            'strategy': vc.STRATEGY,
            'timeframe': vc.TF,
            'holdout_start': vc.HO_2021_START,
            'holdout_end': vc.HO_2021_END,
            'sharpe': round(res.get('sharpe_ratio', 0), 2),
            'trades': res.get('total_trades', 0),
            'total_return': res.get('total_return', 0),
            'win_rate': round(res.get('win_rate', 0), 2),
            'train_bars': res.get('train_bars', 0),
            'test_bars': res.get('test_bars', 0),
            'pass': vc.passes(res),
        }
        rows.append(row)
        print(f"  {symbol:<12} sharpe={row['sharpe']:>6.2f}  "
              f"trades={row['trades']:>4}  {'PASS' if row['pass'] else 'FAIL'}")

    payload = {
        'generated_at': vc.now_ts(),
        'strategy': vc.STRATEGY,
        'timeframe': vc.TF,
        'rows': rows,
        'summary': {'passed': sum(1 for r in rows if 'error' not in r and r['pass'])},
    }
    vc.write_json(vc.BACKTEST_DIR / 'holdout_21_22.json', payload)

    print(f"\nThird-period (2021-2022) passed: {payload['summary']['passed']}/{len(rows)}")


if __name__ == '__main__':
    main()