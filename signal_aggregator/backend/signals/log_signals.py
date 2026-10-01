"""Append the latest ML signal run to a permanent, auditable history log.

Reads signal_aggregator/data/signals/ml_latest.json and appends the whole
document to signal_aggregator/data/signals/signal_history.json (a JSON array,
one entry per run). The Flutter app reads the history from GitHub raw to score
the model's real-world performance.

Paths resolve from this file, not the CWD. Re-running on an unchanged
ml_latest.json is a no-op (entries are keyed by their `timestamp`).
"""
import json
import os
import sys
from pathlib import Path

SIGNALS_DIR = Path(__file__).resolve().parents[2] / 'data' / 'signals'
LATEST = SIGNALS_DIR / 'ml_latest.json'
HISTORY = SIGNALS_DIR / 'signal_history.json'


def load_history(path):
    if not path.exists() or path.stat().st_size == 0:
        return []
    with open(path) as f:
        data = json.load(f)  # corrupt history must fail loudly, never be overwritten
    if not isinstance(data, list):
        raise ValueError(f'{path} is not a JSON array')
    return data


def main():
    if not LATEST.exists():
        print(f'{LATEST} missing; nothing to log')
        return 0
    with open(LATEST) as f:
        run = json.load(f)
    if not run.get('signals'):
        print('ml_latest.json has no signals; nothing to log')
        return 0

    history = load_history(HISTORY)
    if any(h.get('timestamp') == run.get('timestamp') for h in history):
        print(f"Run {run.get('timestamp')} already logged; skipping")
        return 0

    history.append(run)
    tmp = HISTORY.with_suffix('.json.tmp')
    with open(tmp, 'w') as f:
        json.dump(history, f, indent=2)
    os.replace(tmp, HISTORY)
    print(f'Logged run {run.get("timestamp")} ({len(run["signals"])} signals); history now {len(history)} runs')
    return 0


if __name__ == '__main__':
    sys.exit(main())
