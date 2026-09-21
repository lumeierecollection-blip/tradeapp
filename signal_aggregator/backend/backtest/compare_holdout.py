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

wf_survivors = set()
ho_survivors = set()

header = f"{'Symbol':<12} {'Strategy':<10} {'TF':<4} {'WF Sharpe':>10} {'HO Sharpe':>10} {'WF>0':>5} {'HO>0':>5} {'Match':>6}"
print(header)
print("-" * 72)

for key in sorted(set(wf_rows.keys()) | set(ho_rows.keys())):
    wf_s = wf_rows.get(key, {}).get('avg_oos_sharpe', 0)
    ho_s = ho_rows.get(key, {}).get('sharpe', 0)
    wf_pos = wf_rows.get(key, {}).get('pct_positive', 0) >= 50 and wf_s > 0.5
    ho_pos = ho_s > 0.5 and ho_rows.get(key, {}).get('trades', 0) >= 5
    match = 'YES' if (wf_s > 0 and ho_s > 0) or (wf_s <= 0 and ho_s <= 0) else 'NO'
    parts = key.split('|')
    if wf_pos:
        wf_survivors.add(key)
    if ho_pos:
        ho_survivors.add(key)
    marker = ''
    if wf_pos and ho_pos:
        marker = ' **'
    elif wf_pos:
        marker = ' *WF'
    elif ho_pos:
        marker = ' *HO'
    print(f"{parts[0]:<12} {parts[1]:<10} {parts[2]:<4} {wf_s:>10.2f} {ho_s:>10.2f} {str(wf_pos):>5} {str(ho_pos):>5} {match:>6}{marker}")

both = wf_survivors & ho_survivors
wf_only = wf_survivors - ho_survivors
ho_only = ho_survivors - wf_survivors

print(f"\nWF survivors: {len(wf_survivors)}")
print(f"HO survivors: {len(ho_survivors)}")
print(f"Both (validated): {len(both)}")
print(f"WF only (failed holdout): {len(wf_only)}")
for k in sorted(wf_only):
    print(f"  {k}")
print(f"HO only (new discoveries): {len(ho_only)}")
for k in sorted(ho_only):
    print(f"  {k}")
