import json
d = json.load(open('signal_aggregator/data/signals/latest.json'))
print('timestamp:', d['timestamp'])
print('signals:', len(d['signals']))
for s in d['signals'][:3]:
    print(f"  {s['symbol']}: {s['signal']} price={s['price']} confidence={s.get('confidence','?')}")
