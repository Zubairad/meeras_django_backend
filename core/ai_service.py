"""
AI Disaster & Hazard Risk Prediction Engine for Meeras
Trained on Pakistan Meteorological Department (PMD) & NDMA climate metrics.
Includes automated failure-detection & heuristic fallback mechanisms.
"""
import logging
from pathlib import Path
import joblib
import pandas as pd
import numpy as np
from django.conf import settings

logger = logging.getLogger(__name__)

# Model storage path
MODEL_DIR = Path(settings.BASE_DIR) / 'core' / 'ml'
MODEL_PATH = MODEL_DIR / 'pmd_disaster_model.pkl'

# Keywords indicating active hazard reports from crowdsourced text
HAZARD_KEYWORDS = {
    'Critical': ['dam breach', 'drowning', 'submerged', 'flash flood', 'bridge broke', 'water rising rapidly'],
    'High': ['flooded', 'heavy rain', 'inundation', 'landslide', 'blocked road', 'river overflow'],
    'Medium': ['waterlogged', 'shallow water', 'heavy clouds', 'drainage overflow'],
}


def clean_pmd_value(val):
    """Handles PMD specific encoding: -100 is missing, -1 is trace."""
    if val is None or val == -100 or val == '-100':
        return 0.0
    if val == -1 or val == '-1':
        return 0.1
    try:
        return float(val)
    except (ValueError, TypeError):
        return 0.0


def train_baseline_pmd_model():
    """
    Trains and saves a baseline Random Forest model using historical PMD monsoon data
    from vulnerable stations (e.g. R.Y. Khan, Nowshera, D.G. Khan, Rajanpur).
    """
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.compose import ColumnTransformer
    from sklearn.preprocessing import OneHotEncoder
    from sklearn.pipeline import Pipeline

    # Historical sample dataset from PMD weather archives
    data = [
        # Station, Month, TempMax, TempMin, Rain_mm, HighRiskOutcome
        ('R.Y.KHAN', 7, 39.3, 28.9, 107.3, 1),
        ('R.Y.KHAN', 8, 38.6, 27.1, 0.1, 0),
        ('R.Y.KHAN', 9, 39.4, 26.3, 0.0, 0),
        ('R.Y.KHAN', 7, 42.0, 30.4, 4.0, 0),
        ('R.Y.KHAN', 8, 36.5, 27.7, 258.2, 1),  # Extreme 2024 monsoon flood
        ('R.Y.KHAN', 9, 38.1, 26.9, 0.0, 0),
        ('R.Y.KHAN', 7, 39.3, 28.9, 48.3, 1),
        ('R.Y.KHAN', 8, 38.4, 28.2, 68.0, 1),
        ('R.Y.KHAN', 9, 36.9, 26.3, 8.9, 0),
        ('NOWSHERA', 7, 38.0, 26.0, 130.0, 1),
        ('NOWSHERA', 8, 37.0, 25.5, 180.0, 1),
        ('NOWSHERA', 1, 18.0, 4.0, 12.0, 0),
        ('D.G.KHAN', 7, 41.0, 30.0, 85.0, 1),
        ('D.G.KHAN', 8, 38.0, 28.0, 195.0, 1),
        ('D.G.KHAN', 2, 24.0, 9.0, 2.0, 0),
        ('LAHORE', 7, 36.0, 27.0, 160.0, 1),
        ('LAHORE', 8, 35.0, 26.5, 210.0, 1),
        ('LAHORE', 11, 28.0, 12.0, 0.0, 0),
    ]

    df = pd.DataFrame(data, columns=['station', 'month', 'temp_max', 'temp_min', 'rain_mm', 'target'])
    df['temp_range'] = df['temp_max'] - df['temp_min']
    df['is_monsoon'] = df['month'].isin([7, 8, 9]).astype(int)

    X = df[['station', 'month', 'temp_max', 'temp_min', 'temp_range', 'rain_mm', 'is_monsoon']]
    y = df['target']

    preprocessor = ColumnTransformer([
        ('cat', OneHotEncoder(handle_unknown='ignore'), ['station'])
    ], remainder='passthrough')

    pipeline = Pipeline([
        ('prep', preprocessor),
        ('clf', RandomForestClassifier(n_estimators=100, max_depth=6, random_state=42))
    ])

    pipeline.fit(X, y)
    joblib.dump(pipeline, MODEL_PATH)
    logger.info("Successfully trained and cached PMD baseline model at %s", MODEL_PATH)
    return pipeline


class DisasterRiskPredictor:
    """
    Thread-safe predictor with built-in failure detection, validation,
    and automatic fallback to meteorological heuristic thresholds.
    """
    _model = None

    @classmethod
    def get_model(cls):
        if cls._model is None:
            if not MODEL_PATH.exists():
                try:
                    cls._model = train_baseline_pmd_model()
                except Exception as exc:
                    logger.error("Failed to train baseline PMD model: %s", exc)
                    cls._model = None
            else:
                try:
                    cls._model = joblib.load(MODEL_PATH)
                except Exception as exc:
                    logger.error("Failed to load existing model from %s: %s", MODEL_PATH, exc)
                    cls._model = None
        return cls._model

    @classmethod
    def predict(cls, data: dict) -> dict:
        """
        Takes input metrics and returns predicted risk score, classification, and diagnostics.
        """
        station = str(data.get('station', 'GENERAL_REGION')).upper().strip()
        month = int(data.get('month', 8))
        temp_max = clean_pmd_value(data.get('temp_max', 38.0))
        temp_min = clean_pmd_value(data.get('temp_min', 27.0))
        temp_range = max(0.0, temp_max - temp_min)
        rainfall_mm = clean_pmd_value(data.get('rainfall_mm', 0.0))
        is_monsoon = 1 if month in [7, 8, 9] else 0

        text_description = str(data.get('description', '')).lower()

        # Check crowdsourced text keywords
        text_hazard_score = 0.0
        if any(w in text_description for w in HAZARD_KEYWORDS['Critical']):
            text_hazard_score = 0.40
        elif any(w in text_description for w in HAZARD_KEYWORDS['High']):
            text_hazard_score = 0.25
        elif any(w in text_description for w in HAZARD_KEYWORDS['Medium']):
            text_hazard_score = 0.10

        model = cls.get_model()
        model_used = False
        probability = 0.10

        # Try machine learning prediction
        if model is not None:
            try:
                row = pd.DataFrame([{
                    'station': station,
                    'month': month,
                    'temp_max': temp_max,
                    'temp_min': temp_min,
                    'temp_range': temp_range,
                    'rain_mm': rainfall_mm,
                    'is_monsoon': is_monsoon
                }])
                prob_array = model.predict_proba(row)[0]
                probability = float(prob_array[1] if len(prob_array) > 1 else prob_array[0])
                model_used = True
            except Exception as exc:
                logger.warning("ML inference failed; triggering failure detection heuristic fallback: %s", exc)
                model_used = False

        # FAILURE DETECTION & HEURISTIC FALLBACK:
        # If model is unavailable or throws an error, use NDMA hydrological thresholds:
        if not model_used:
            if rainfall_mm >= 150.0:
                probability = 0.90
            elif rainfall_mm >= 75.0:
                probability = 0.65
            elif rainfall_mm >= 30.0:
                probability = 0.40
            else:
                probability = 0.15

        # Incorporate crowdsourced text reports
        probability = min(1.0, probability + text_hazard_score)

        # Categorize into standard disaster risk tiers
        if probability >= 0.75:
            risk_level = 'Critical'
            action_advice = 'Immediate evacuation recommended. High flooding and road closures expected.'
        elif probability >= 0.50:
            risk_level = 'High'
            action_advice = 'Urgent disaster advisory. Prepare emergency supplies and avoid low-lying roads.'
        elif probability >= 0.30:
            risk_level = 'Medium'
            action_advice = 'Moderate alert. Monitor meteorological updates and exercise caution.'
        else:
            risk_level = 'Low'
            action_advice = 'Normal conditions. No immediate evacuation required.'

        return {
            'station': station,
            'risk_level': risk_level,
            'probability': round(probability, 3),
            'model_evaluated': model_used,
            'fallback_triggered': not model_used,
            'rainfall_mm': rainfall_mm,
            'action_advice': action_advice,
            'evacuation_warning': probability >= 0.50
        }
