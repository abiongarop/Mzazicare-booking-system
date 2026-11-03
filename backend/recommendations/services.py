import json
import logging
from functools import lru_cache
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import shap

from django.conf import settings

logger = logging.getLogger(__name__)

# Project root is the parent of the backend directory.
PROJECT_ROOT = Path(settings.BASE_DIR).parent
MODEL_DIR = PROJECT_ROOT / "ml" / "models"

MODEL_PATH = MODEL_DIR / "caregiver_random_forest.pkl"
FEATURE_PATH = MODEL_DIR / "feature_columns.json"


FEATURE_LABELS = {
    "service_match": "Required service match",
    "skill_match": "Required skill match",
    "location_match": "Location match",
    "availability_match": "Availability match",
    "experience_years": "Caregiving experience",
    "experience_match": "Minimum experience requirement",
    "rating": "Caregiver rating",
    "distance_km": "Distance from the family",
}


@lru_cache(maxsize=1)
def load_model_and_features():
    """Load the trained model and its exact training feature order."""

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
        raise ValueError(
            "Feature columns must be a non-empty list."
        )

    model_features = getattr(model, "feature_names_in_", None)

    if model_features is not None:
        if list(model_features) != features:
            raise ValueError(
                "feature_columns.json does not match the "
                "features used when training the model."
            )

    if not hasattr(model, "predict_proba"):
        raise TypeError(
            "The trained model must support predict_proba()."
        )

    return model, features


def _positive_class_shap_values(values, positive_index):
    """
    Normalize SHAP output across common SHAP versions.

    Returns a 2D array:
        rows x features
    """

    if isinstance(values, list):
        # Older SHAP versions return one array per class.
        if positive_index >= len(values):
            raise ValueError("Positive class is missing from SHAP output.")

        values = values[positive_index]

    values = np.asarray(values)

    if values.ndim == 3:
        # Common newer format:
        # rows x features x classes
        if values.shape[-1] > positive_index:
            values = values[:, :, positive_index]
        else:
            raise ValueError("Positive class is missing from SHAP output.")

    if values.ndim != 2:
        raise ValueError(
            f"Unexpected SHAP output dimensions: {values.shape}"
        )

    return values


def _positive_class_baseline(explainer, positive_index):
    """Get the expected model output for the positive class."""

    expected = np.asarray(explainer.expected_value)

    if expected.ndim == 0:
        return float(expected)

    expected = expected.flatten()

    if positive_index >= len(expected):
        raise ValueError("Positive class baseline is unavailable.")

    return float(expected[positive_index])


def explain_predictions(
    model,
    features,
    feature_names,
    positive_index=1,
):
    """
    Explain each prediction using SHAP.

    A positive contribution means the feature pushed the prediction
    towards the positive suitability class.

    A negative contribution means the feature pushed the prediction
    away from the positive suitability class.

    The contribution values are SHAP model-output contributions.
    They should not automatically be described as percentages.
    """

    try:
        explainer = shap.TreeExplainer(model)

        shap_output = explainer.shap_values(features)

        shap_values = _positive_class_shap_values(
            shap_output,
            positive_index,
        )

        if shap_values.shape != (
            len(features),
            len(feature_names),
        ):
            raise ValueError(
                "SHAP output does not match the input feature dimensions."
            )

        baseline = _positive_class_baseline(
            explainer,
            positive_index,
        )

        results = []

        for row_values in shap_values:
            contributions = []

            for name, value in zip(feature_names, row_values):
                contribution = float(value)

                if contribution > 0:
                    impact = "increased"
                    explanation = (
                        f"{FEATURE_LABELS.get(name, name)} "
                        "increased caregiver suitability."
                    )
                elif contribution < 0:
                    impact = "decreased"
                    explanation = (
                        f"{FEATURE_LABELS.get(name, name)} "
                        "reduced caregiver suitability."
                    )
                else:
                    impact = "neutral"
                    explanation = (
                        f"{FEATURE_LABELS.get(name, name)} "
                        "had little or no effect on this prediction."
                    )

                contributions.append({
                    "feature": name,
                    "label": FEATURE_LABELS.get(name, name),
                    "contribution": round(contribution, 6),
                    "impact": impact,
                    "explanation": explanation,
                })

            # Strongest factors first, whether positive or negative.
            contributions.sort(
                key=lambda item: abs(item["contribution"]),
                reverse=True,
            )

            results.append(contributions[:5])

        return results

    except Exception:
        logger.exception(
            "SHAP explanation generation failed."
        )

        # Do not invent explanations when SHAP fails.
        return [[] for _ in range(len(features))]


def rank_candidates(candidate_rows):
    """
    Rank caregivers using the trained Random Forest model.

    Each candidate must contain:
      - caregiver_id
      - the eight trained model features

    Returns a list ordered by predicted suitability.
    """

    if not candidate_rows:
        return []

    model, feature_names = load_model_and_features()

    frame = pd.DataFrame(candidate_rows)

    if "caregiver_id" not in frame.columns:
        raise ValueError(
            "Candidate data must contain caregiver_id."
        )

    missing = [
        name for name in feature_names
        if name not in frame.columns
    ]

    if missing:
        raise ValueError(
            f"Candidate data is missing model features: {missing}"
        )

    X = frame[feature_names].apply(
        pd.to_numeric,
        errors="raise",
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
        model=model,
        features=X,
        feature_names=feature_names,
        positive_index=positive_index,
    )

    ranked = []

    # enumerate() ensures predictions match rows even when the
    # DataFrame has non-sequential indexes.
    for position, (_, row) in enumerate(frame.iterrows()):

        ranked.append({
            "caregiver_id": str(row["caregiver_id"]),
            "suitability_score": round(
                float(scores[position]) * 100,
                2,
            ),
            "explanation": explanations[position],
        })

    ranked.sort(
        key=lambda item: item["suitability_score"],
        reverse=True,
    )

    return ranked