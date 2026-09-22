"""Shared helpers for survivor validation runs (sibling + third-period)."""
import json
import os
import subprocess
import sys
from datetime import datetime, UTC
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
ENGINE = REPO_ROOT / 'signal_aggregator' / 'backend' / 'backtest' / 'engine.py'
BACKTEST_DIR = REPO_ROOT / 'data' / 'backtest'
HO_2023 = '2023-01-01'
HO_2021_START = '2021-01-01'
HO_2021_END = '2023-01-01'
STRATEGY = 'ma_cross'
TF = '1d'

SURVIVORS = ['GC=F', 'USDJPY=X', '^GSPC', '^NDX']

SIBLING_MAP = {
    'GC=F':     ['SI=F', 'PL=F'],
    'USDJPY=X': ['USDCHF=X', 'EURJPY=X', 'GBPJPY=X'],
    '^GSPC':    ['^NDX', '^DJI', '^RUT'],
    '^NDX':     ['^GSPC', '^RUT', '^DJI'],
}


def read_json(path, default=None):
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return default


def write_json(path, payload):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        json.dump(payload, f, indent=2)


def trigger_holdout(symbol, holdout_start, holdout_end=None):
    """Run engine.py holdout via subprocess; returns parsed holdout.json result."""
    cmd = [sys.executable, str(ENGINE),
           '--symbol', symbol,
           '--strategy', STRATEGY,
           '--timeframe', TF,
           '--holdout-start', holdout_start]
    if holdout_end:
        cmd += ['--holdout-end', holdout_end]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=300, cwd=str(REPO_ROOT))
    except subprocess.TimeoutExpired:
        return {'error': 'timeout'}
    if r.returncode != 0:
        return {'error': (r.stderr or r.stdout)[-300:]}
    out = BACKTEST_DIR / 'holdout.json'
    if not os.path.exists(out):
        return {'error': 'missing data/backtest/holdout.json'}
    return read_json(out, {'error': 'empty holdout.json'})


def passes(result):
    return bool(result) and result.get('sharpe_ratio', 0) > 0.5 and result.get('total_trades', 0) >= 5


def now_ts():
    return datetime.now(UTC).isoformat()