"""Task 3 — Combined validation verdict.

Reads walk-forward, 2023-2026 holdout, 2021-2022 holdout, and sibling
results for the 4 survivors and writes data/backtest/validation_summary.json.

Verdict rules:
- confirmed: holdout23-26 pass AND holdout21-22 pass AND >=60% siblings pass
- partial:   2 of 3 tests
- failed:    0-1 tests
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validation_common as vc


def holdout_pass(sharpe, trades):
    return sharpe > 0.5 and trades >= 5


def main():
    wf = vc.read_json(vc.BACKTEST_DIR / 'wf_matrix.json', {'rows': []})
    ho23 = vc.read_json(vc.BACKTEST_DIR / 'holdout_matrix.json', None)
    if ho23 is None:
        ho23 = vc.read_json(vc.REPO_ROOT / 'signal_aggregator' / 'data' / 'backtest' / 'holdout_matrix.json',
                            {'rows': []})
    tp = vc.read_json(vc.BACKTEST_DIR / 'holdout_21_22.json', {'rows': []})
    sib = vc.read_json(vc.BACKTEST_DIR / 'sibling_check.json', {'rows': []})

    wf_map = {}
    for r in wf['rows']:
        if r.get('strategy') == vc.STRATEGY and r.get('tf') == vc.TF:
            wf_map[r['symbol']] = r.get('avg_oos_sharpe', 0)

    ho23_map = {}
    for r in ho23['rows']:
        if 'error' not in r and r.get('strategy') == vc.STRATEGY and r.get('tf') == vc.TF:
            ho23_map[r['symbol']] = r

    tp_map = {}
    for r in tp['rows']:
        if 'error' not in r:
            tp_map[r['symbol']] = r

    sib_map = {}
    for r in sib['rows']:
        if 'error' not in r:
            group = sib_map.setdefault(r['survivor'], [])
            group.append(r)

    survivors = []
    counts = {'confirmed': 0, 'partial': 0, 'failed': 0}

    print(f"{'Symbol':<12} {'WF':>7} {'HO23-26':>8} {'HO21-22':>8} {'Sib%':>6} {'Verdict':<10}")
    print('-' * 60)

    for symbol in vc.SURVIVORS:
        wf_s = round(wf_map.get(symbol, 0), 2)

        h23 = ho23_map.get(symbol, {})
        h23_s = round(h23.get('sharpe', 0), 2)
        h23_ok = holdout_pass(h23.get('sharpe', 0), h23.get('trades', 0))

        t21 = tp_map.get(symbol, {})
        t21_s = round(t21.get('sharpe', 0), 2)
        t21_ok = holdout_pass(t21.get('sharpe', 0), t21.get('trades', 0))

        siblings = sib_map.get(symbol, [])
        sib_rate = (sum(1 for s in siblings if s['pass']) / len(siblings) * 100) if siblings else 0.0
        sib_ok = sib_rate >= 60.0

        tests_passed = sum([h23_ok, t21_ok, sib_ok])
        if h23_ok and t21_ok and sib_ok:
            verdict = 'confirmed'
        elif tests_passed >= 2:
            verdict = 'partial'
        else:
            verdict = 'failed'
        counts[verdict] += 1

        survivors.append({
            'symbol': symbol,
            'wf': wf_s,
            'holdout_23_26': h23_s,
            'holdout_21_22': t21_s,
            'siblings_pass_rate': round(sib_rate, 1),
            'verdict': verdict,
        })
        print(f"{symbol:<12} {wf_s:>7.2f} {h23_s:>8.2f} {t21_s:>8.2f} {round(sib_rate):>5}% {verdict:<10}")

    payload = {
        'generated_at': vc.now_ts(),
        'strategy': vc.STRATEGY,
        'timeframe': vc.TF,
        'survivors': survivors,
        'overall': {
            'confirmed_count': counts['confirmed'],
            'partial_count': counts['partial'],
            'failed_count': counts['failed'],
        },
    }
    vc.write_json(vc.BACKTEST_DIR / 'validation_summary.json', payload)

    print(f"\nconfirmed={counts['confirmed']} partial={counts['partial']} failed={counts['failed']}")


if __name__ == '__main__':
    main()