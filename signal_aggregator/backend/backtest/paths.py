"""Canonical output paths for backtest scripts, resolved from this file (not CWD).

The Flutter app reads signal_aggregator/data/backtest/ from GitHub raw, so every
backtest/validation script must write there regardless of where it is run from.
"""
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent
_BACKEND_DIR = _SCRIPT_DIR.parent
REPO_ROOT = _BACKEND_DIR.parent.parent
ENGINE = _SCRIPT_DIR / 'engine.py'
BACKTEST_DIR = REPO_ROOT / 'signal_aggregator' / 'data' / 'backtest'
BACKTEST_DIR.mkdir(parents=True, exist_ok=True)
