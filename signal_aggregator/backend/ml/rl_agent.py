# TODO: train DQN
"""Reinforcement learning agent for trade recommendations.

Advisory only - not trained yet.
"""


def advise(features: dict) -> dict:
    """Return an advisory recommendation.

    Args:
        features: Market features dict with price, rsi, volume, etc.

    Returns:
        dict: Recommendation with HOLD status and note.
    """
    return {"recommendation": "HOLD", "confidence": 0.0, "note": "advisor not yet trained"}


if __name__ == "__main__":
    import json
    result = advise({})
    print(json.dumps(result))
