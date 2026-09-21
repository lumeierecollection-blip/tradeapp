"""FinBERT-based sentiment scorer for financial headlines.

Uses ProsusAI/finbert via transformers pipeline.
Falls back to a lightweight lexicon if the model can't be loaded
(GitHub Actions free tier may hit memory limits on first download).
"""
from functools import lru_cache

@lru_cache(maxsize=1)
def _pipeline():
    try:
        from transformers import pipeline
        return pipeline("sentiment-analysis", model="ProsusAI/finbert")
    except Exception as e:
        print(f"[finbert] load failed, using lexicon fallback: {e}")
        return None

POSITIVE = {"beat", "rally", "surge", "gain", "strong", "upgrade", "bullish"}
NEGATIVE = {"miss", "plunge", "drop", "weak", "downgrade", "bearish", "fear"}

def score(text: str) -> dict:
    """Return {'label': 'positive'|'negative'|'neutral', 'score': 0.0-1.0}"""
    pipe = _pipeline()
    if pipe is not None:
        try:
            r = pipe(text[:512])[0]
            return {"label": r["label"].lower(), "score": float(r["score"])}
        except Exception:
            pass
    lower = text.lower()
    pos = sum(1 for w in POSITIVE if w in lower)
    neg = sum(1 for w in NEGATIVE if w in lower)
    if pos > neg:
        return {"label": "positive", "score": min(0.6 + 0.1 * pos, 0.95)}
    if neg > pos:
        return {"label": "negative", "score": min(0.6 + 0.1 * neg, 0.95)}
    return {"label": "neutral", "score": 0.5}
