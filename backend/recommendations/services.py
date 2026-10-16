
import json
import os
from functools import lru_cache
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import shap

from django.conf import settings


# Project root is the parent of the backend directory.
PROJECT_ROOT = Path(settings.BASE_DIR).parent
MODEL_DIR = PROJECT_ROOT / "ml" / "models"

MODEL_PATH = MODEL_DIR / "caregiver_random_forest.pkl"
FEATURE_PATH = MODEL_DIR / "feature_columns.json"


@lru_cache(maxsize=1)
def load_model_and_features():
    if not MODEL_PATH.exists():
        raise FileNotFoundError(
            f"Trained model not found: {MODEL_PATH}"
        )

    if not FEATURE_PATH.exists():
        raise FileNotFoundError(
            f"Feature file not found: {FEATURE_PATH}"
        )

    model = joblib.load(MODEL_PATH)

    with FEATURE_PATH.open("r", encoding="utf-8") as file:
        features = json.load(file)

    if not isinstance(features, list) or not features:
        raise ValueError("Feature columns must be a non-empty list.")

    model_features = getattr(model, "feature_names_in_", None)

    if model_features is not None:
        if list(model_features) != features:
            raise ValueError(
                "feature_columns.json does not match the "
                "features used when training the model."
            )

    return model, features


def explain_predictions(model, features, feature_names):
    """
    Return per-feature SHAP contributions for a fitted tree model.
    Explanations must use the same feature representation as training.
    """
    try:
        explainer = shap.TreeExplainer(model)
        values = explainer.shap_values(features)

        # For binary classification, some SHAP versions return
        # a list with one array per class.
        if isinstance(values, list):
            values = values[-1]

        # Some versions return (rows, features, classes).
        if getattr(values, "ndim", 0) == 3:
            values = values[:, :, -1]

        if values.ndim != 2:
            return [[] for _ in range(len(features))]

        results = []

        for row_values in values:
            contributions = [
                {
                    "feature": name,
                    "contribution": round(float(value), 4),
                }
                for name, value in zip(feature_names, row_values)
            ]

            contributions.sort(
                key=lambda item: abs(item["contribution"]),
                reverse=True,
            )
            results.append(contributions[:5])

        return results

    except Exception:
        # Do not fabricate explanations if SHAP fails.
        return [[] for _ in range(len(features))]


def rank_candidates(candidate_rows):
    """
    candidate_rows: list of dictionaries containing caregiver_id
    and the eight trained model features.

    Returns candidates ranked by predicted suitability probability.
    """
    model, feature_names = load_model_and_features()

    if not candidate_rows:
        return []

    frame = pd.DataFrame(candidate_rows)

    missing = [
        name for name in feature_names
        if name not in frame.columns
    ]

    if missing:
        raise ValueError(
            f"Candidate data is missing model features: {missing}"
        )

    X = frame[feature_names].apply(
        pd.to_numeric, errors="raise"
    )

    if not np.isfinite(X.to_numpy(dtype=float)).all():
        raise ValueError(
            "Candidate features contain missing or infinite values."
        )

    probabilities = model.predict_proba(X)

    classes = list(model.classes_)

    if 1 not in classes:
        raise ValueError(
            "The trained model has no positive suitability class (1)."
        )

    positive_index = classes.index(1)
    scores = probabilities[:, positive_index]

    explanations = explain_predictions(
        model, X, feature_names
    )

    ranked = []

    for index, row in frame.iterrows():
        ranked.append({
            "caregiver_id": str(row["caregiver_id"]),
            "suitability_score": round(
                float(scores[index]) * 100, 2
            ),
            "explanation": explanations[index],
        })

    ranked.sort(
        key=lambda item: item["suitability_score"],
        reverse=True,
    )

    return ranked