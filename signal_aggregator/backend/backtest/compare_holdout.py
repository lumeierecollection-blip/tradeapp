import json

wf = json.load(open('data/backtest/wf_matrix.json'))
ho = json.load(open('data/backtest/holdout_matrix.json'))

wf_rows = {}
ho_rows = {}

for r in wf['rows']:
    if 'error' not in r:
        key = r['symbol'] + '|' + r['strategy'] + '|' + r['tf']
        wf_rows[key] = r

for r in ho['rows']:
    if 'error' not in r:
        key = r['symbol'] + '|' + r['strategy'] + '|' + r['tf']
        ho_rows[key] = r

print(f"{'Symbol':<12} {'Strategy':<10} {'TF':<4} {'WF Sharpe':>10} {'HO Sharpe':>10} {'Match':>6}")
print("-" * 56)

for key in sorted(set(wf_rows.keys()) | set(ho_rows.keys())):
    wf_s = wf_rows.get(key, {}).get('avg_oos_sharpe', 0)
    ho_s = ho_rows.get(key, {}).get('sharpe', 0)
    match = 'YES' if (wf_s > 0 and ho_s > 0) or (wf_s < 0 and ho_s < 0) else 'NO'
    parts = key.split('|')
    print(f"{parts[0]:<12} {parts[1]:<10} {parts[2]:<4} {wf_s:>10.2f} {ho_s:>10.2f} {match:>6}")

wf_survivors = set()
ho_survivors = set()

for key, r in wf_rows.items():
    if r.get('pct_positive', 0) >= 50 and r.get('avg_oos_sharpe', 0) > 0.5:
        wf_survivors.add(key)

for key, r in ho_rows.items():
    if r.get('sharpe', 0) > 0.5 and r.get('trades', 0) >= 5:
        ho_survivors.add(key)

both = wf_survivors & ho_survivors
wf_only = wf_survivors - ho_survivors

print(f"\nTotal combos: 80 (40 daily + 40 hourly — hourly unavailable via Yahoo)")
print(f"Holdout survivors (sharpe>0.5, trades>=5): {len(ho_survivors)}")
print(f"WF survivors that also survived holdout: {len(both)}")
print(f"WF survivors that failed holdout: {len(wf_only)}")
for k in sorted(wf_only):
    print(f"  {k}")
