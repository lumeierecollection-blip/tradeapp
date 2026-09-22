"""Regime-filtered validation for the 4 survivors.

Runs walk-forward (8 windows), holdout 2023-2026 and holdout 2021-2022
WITH --regime-filter and compares against the committed no-filter baselines.

Verdicts:
- confirmed : all 3 tests pass (sharpe > 0.5) with regime filter
- improved  : 1-2 tests went from fail to pass
- unchanged : same pass/fail pattern
- worsened  : any test went from pass to fail

Writes data/backtest/regime_validation.json.
"""
import json
import subprocess
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validation_common as vc


def subprocess_run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=300, cwd=str(vc.REPO_ROOT))


def _wf(symbol, regime_filter=False):
    cmd = [sys.executable, str(vc.ENGINE),
           '--symbol', symbol, '--strategy', vc.STRATEGY, '--timeframe', vc.TF,
           '--walk-forward']
    if regime_filter:
        cmd.append('--regime-filter')
    r = subprocess_run(cmd)
    if r.returncode != 0:
        return {'error': (r.stderr or r.stdout)[-200:]}
    return vc.read_json(vc.BACKTEST_DIR / 'walkforward.json', {})


def _holdout(symbol, start, end=None, regime_filter=False):
    res = vc.trigger_holdout(symbol, start, end, regime_filter=regime_filter)
    if 'error' in res:
        return res
    return {'sharpe': res.get('sharpe_ratio', 0), 'trades': res.get('total_trades', 0)}


def _holdout_pass(res):
    return bool(res) and res.get('sharpe', 0) > 0.5 and res.get('trades', 0) >= 5


def _wf_pass(sharpe):
    return sharpe > 0.5


def base_val(rows, key):
    for r in rows:
        if 'error' in r:
            continue
        tf = r.get('tf') or r.get('timeframe')
        if r.get('strategy') == vc.STRATEGY and tf == vc.TF \
                and r.get('symbol') == key:
            return r
    return {}


def main():
    wf_base = vc.read_json(vc.BACKTEST_DIR / 'wf_matrix.json', {'rows': []})
    ho23_base = vc.read_json(vc.BACKTEST_DIR / 'holdout_matrix.json', {'rows': []})
    if not ho23_base['rows']:
        ho23_base = vc.read_json(
            vc.REPO_ROOT / 'signal_aggregator' / 'data' / 'backtest' / 'holdout_matrix.json',
            {'rows': []})
    ho21_base = vc.read_json(vc.BACKTEST_DIR / 'holdout_21_22.json', {'rows': []})

    tests = ['WF', 'HO23-26', 'HO21-22']
    survivors = []

    print(f"{'Symbol':<12} {'Test':<9} {'NoFilter':>9} {'WithFilter':>10} {'Delta':>8}")
    print('-' * 55)

    for symbol in vc.SURVIVORS:
        base = {
            'WF': base_val(wf_base['rows'], symbol).get('avg_oos_sharpe', 0),
            'HO23-26': base_val(ho23_base['rows'], symbol).get('sharpe', 0),
            'HO21-22': base_val(ho21_base['rows'], symbol).get('sharpe', 0),
        }

        wf_res = _wf(symbol, regime_filter=True)
        if 'error' in wf_res:
            new = {'WF': {'error': wf_res['error']}}
        else:
            new = {'WF': {'sharpe': wf_res.get('avg_test_sharpe', 0), 'trades': 0}}
        new['HO23-26'] = _holdout(symbol, vc.HO_2023, regime_filter=True)
        new['HO21-22'] = _holdout(symbol, vc.HO_2021_START, vc.HO_2021_END, regime_filter=True)

        for t in tests:
            old_s = base[t]
            n_s = new[t].get('sharpe', 0)
            delta = n_s - old_s
            if 'error' in new[t]:
                print(f"{symbol:<12} {t:<9} {old_s:>9.2f} {'ERROR':>10} {'--':>8}")
            else:
                print(f"{symbol:<12} {t:<9} {old_s:>9.2f} {n_s:>10.2f} {delta:>+8.2f}")

        old_flags = [('WF', base['WF'] > 0.5),
                     ('HO23-26', base['HO23-26'] > 0.5),
                     ('HO21-22', base['HO21-22'] > 0.5)]
        new_flags = [('WF', _wf_pass(new['WF'].get('sharpe', 0))),
                     ('HO23-26', _holdout_pass(new['HO23-26'])),
                     ('HO21-22', _holdout_pass(new['HO21-22']))]

        all_pass = all(f for _, f in new_flags)
        improved = sum(1 for (tn, o), (tw, n) in zip(old_flags, new_flags) if not o and n)
        worsened = sum(1 for (tn, o), (tw, n) in zip(old_flags, new_flags) if o and not n)

        if all_pass:
            verdict = 'confirmed'
        elif improved >= 1 and worsened == 0:
            verdict = 'improved'
        elif worsened > 0:
            verdict = 'worsened'
        else:
            verdict = 'unchanged'

        survivors.append({
            'symbol': symbol,
            'no_filter': {'wf': round(base['WF'], 2),
                          'holdout_23_26': round(base['HO23-26'], 2),
                          'holdout_21_22': round(base['HO21-22'], 2)},
            'with_filter': {'wf': round(new['WF'].get('sharpe', 0), 2),
                            'holdout_23_26': round(new['HO23-26'].get('sharpe', 0), 2),
                            'holdout_21_22': round(new['HO21-22'].get('sharpe', 0), 2)},
            'old_pass': {n: f for n, f in old_flags},
            'new_pass': {n: f for n, f in new_flags},
            'verdict': verdict,
        })
        print(f"{symbol:<12} {'VERDICT':<9} {'':>9} {'':>10} {'':>8}  {verdict}")
        print()

    with open(vc.BACKTEST_DIR / 'regime_validation.json', 'w') as f:
        json.dump({'generated_at': vc.now_ts(),
                   'strategy': vc.STRATEGY,
                   'timeframe': vc.TF,
                   'survivors': survivors}, f, indent=2)

    counts = Counter(s['verdict'] for s in survivors)
    print('=' * 55)
    print(f"SUMMARY — Confirmed after filter: {counts['confirmed']}, "
          f"Improved: {counts['improved']}, "
          f"Unchanged: {counts['unchanged']}, "
          f"Worsened: {counts['worsened']}")
    cands = [s['symbol'] for s in survivors if s['verdict'] == 'confirmed']
    print(f"TRADEABLE CANDIDATES (3/3 with filter): {cands if cands else '(none)'}")


if __name__ == '__main__':
    main()