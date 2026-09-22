"""Task 1 — Sibling-asset holdout validation.

For each survivor S and each sibling X in SIBLING_MAP[S], run holdout
validation on X with ma_cross 1d (train 2016-2022, test 2023-2026) and
record symbol, sharpe, trades, win_rate into data/backtest/sibling_check.json.

Pass criteria per sibling: sharpe > 0.5 AND trades >= 5.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validation_common as vc


def main():
    rows = []
    for survivor, siblings in vc.SIBLING_MAP.items():
        for sibling in siblings:
            res = vc.trigger_holdout(sibling, vc.HO_2023)
            if 'error' in res:
                rows.append({'survivor': survivor, 'symbol': sibling, 'error': res['error']})
                print(f"  {survivor:<10} {sibling:<12} ERROR: {res['error'][:80]}")
                continue
            row = {
                'survivor': survivor,
                'symbol': sibling,
                'strategy': vc.STRATEGY,
                'timeframe': vc.TF,
                'sharpe': round(res.get('sharpe_ratio', 0), 2),
                'trades': res.get('total_trades', 0),
                'win_rate': round(res.get('win_rate', 0), 2),
                'total_return': res.get('total_return', 0),
                'pass': vc.passes(res),
            }
            rows.append(row)
            print(f"  {survivor:<10} {sibling:<12} "
                  f"sharpe={row['sharpe']:>6.2f}  "
                  f"trades={row['trades']:>4}  win%={row['win_rate']:>5.1f}  "
                  f"{'PASS' if row['pass'] else 'FAIL'}")

    valid = [r for r in rows if 'error' not in r]
    passed = [r for r in valid if r['pass']]

    payload = {
        'generated_at': vc.now_ts(),
        'holdout_start': vc.HO_2023,
        'strategy': vc.STRATEGY,
        'timeframe': vc.TF,
        'pass_criteria': 'sharpe > 0.5 AND trades >= 5',
        'rows': rows,
        'summary': {
            'total_sibling_tests': len(valid),
            'errors': len(rows) - len(valid),
            'passed': len(passed),
            'pass_rate': round(len(passed) / len(valid) * 100, 1) if valid else 0.0,
        },
    }
    vc.write_json(vc.BACKTEST_DIR / 'sibling_check.json', payload)

    print(f"\nTotal sibling tests: {len(valid)}")
    print(f"Passed: {len(passed)}")
    print(f"Pass rate: {payload['summary']['pass_rate']}%")

    by_class = {'precious metals': [], 'JPY crosses': [], 'indices': []}
    for r in valid:
        sib = r['symbol']
        if sib in ('SI=F', 'PL=F'):
            by_class['precious metals'].append(r['pass'])
        elif sib in ('USDCHF=X', 'EURJPY=X', 'GBPJPY=X'):
            by_class['JPY crosses'].append(r['pass'])
        else:
            by_class['indices'].append(r['pass'])
    rates = {k: (sum(v) / len(v) * 100 if v else 0) for k, v in by_class.items()}
    best = max(rates, key=rates.get)
    print(f"Most-consistent class: {best} ({rates[best]:.0f}%)")


if __name__ == '__main__':
    main()