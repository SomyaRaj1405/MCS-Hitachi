"""
app.py — MCS ML Service

A small FastAPI service, separate from the Spring Boot backend, serving:
  - POST /predict/fraud            — anomaly-based fraud risk scoring
  - POST /predict/revenue-forecast — predictive analytics on revenue trend

Run locally with:
    uvicorn app:app --reload --port 8000

Spring Boot's FraudCheckConsumer calls /predict/fraud after each settled
transaction. The Flutter dashboard (via a new Spring Boot endpoint) can
call /predict/revenue-forecast to show a forecasted revenue chart.
"""

from fastapi import FastAPI
from pydantic import BaseModel, Field
from typing import List
import joblib
import pandas as pd
import numpy as np

app = FastAPI(title="MCS ML Service", version="1.0")

# --- Load the trained fraud model at startup ---
_bundle = joblib.load("fraud_model.joblib")
fraud_model = _bundle["model"]
fraud_features = _bundle["features"]


# ---------- Fraud prediction ----------

class FraudCheckRequest(BaseModel):
    amount: float = Field(..., description="Transaction amount")
    hour_of_day: int = Field(..., ge=0, le=23, description="Hour transaction occurred, 0-23")
    customer_txn_count_24h: int = Field(..., ge=0, description="Customer's transaction count in the last 24h")
    merchant_avg_amount: float = Field(..., description="Merchant's historical average transaction amount")


class FraudCheckResponse(BaseModel):
    flagged: bool
    risk_score: float          # normalized 0 (safe) to 1 (highly suspicious)
    raw_anomaly_score: float   # underlying Isolation Forest score, for debugging/logging


@app.post("/predict/fraud", response_model=FraudCheckResponse)
def predict_fraud(request: FraudCheckRequest):
    merchant_avg = request.merchant_avg_amount if request.merchant_avg_amount > 0 else 1.0
    amount_deviation = (request.amount - merchant_avg) / merchant_avg

    row = pd.DataFrame([{
        "amount": request.amount,
        "hour_of_day": request.hour_of_day,
        "customer_txn_count_24h": request.customer_txn_count_24h,
        "amount_deviation_from_merchant_avg": amount_deviation,
    }])[fraud_features]

    raw_score = float(fraud_model.decision_function(row)[0])
    prediction = int(fraud_model.predict(row)[0])  # -1 = anomaly, 1 = normal

    # Normalize raw_score (~ -0.5 to 0.5 typically) into a 0-1 risk_score for easier use downstream
    risk_score = float(np.clip((0.3 - raw_score) / 0.6, 0.0, 1.0))

    return FraudCheckResponse(
        flagged=(prediction == -1),
        risk_score=round(risk_score, 4),
        raw_anomaly_score=round(raw_score, 4),
    )


# ---------- Revenue forecasting ----------

class RevenuePoint(BaseModel):
    date: str        # "YYYY-MM-DD"
    revenue: float


class ForecastRequest(BaseModel):
    history: List[RevenuePoint] = Field(..., description="Historical daily revenue, chronological order")
    days_ahead: int = Field(7, ge=1, le=30, description="How many days ahead to forecast")


class ForecastPoint(BaseModel):
    date: str
    predicted_revenue: float


class ForecastResponse(BaseModel):
    forecast: List[ForecastPoint]
    trend: str            # "increasing", "decreasing", or "stable"
    daily_growth_rate: float


@app.post("/predict/revenue-forecast", response_model=ForecastResponse)
def forecast_revenue(request: ForecastRequest):
    history = request.history

    if len(history) < 3:
        # Not enough data for a meaningful trend — flat-line the last known value
        last_value = history[-1].revenue if history else 0.0
        last_date = pd.to_datetime(history[-1].date) if history else pd.Timestamp.today()
        forecast = []
        for i in range(1, request.days_ahead + 1):
            forecast.append(ForecastPoint(
                date=(last_date + pd.Timedelta(days=i)).strftime("%Y-%m-%d"),
                predicted_revenue=round(last_value, 2),
            ))
        return ForecastResponse(forecast=forecast, trend="stable", daily_growth_rate=0.0)

    df = pd.DataFrame([h.dict() for h in history])
    df["date"] = pd.to_datetime(df["date"])
    df = df.sort_values("date").reset_index(drop=True)
    df["day_index"] = np.arange(len(df))

    # Simple linear regression over day_index -> revenue.
    # Deliberately simple and explainable for a project demo — a straight
    # line fit through recent history, rather than a black-box model.
    coeffs = np.polyfit(df["day_index"], df["revenue"], deg=1)
    slope, intercept = coeffs[0], coeffs[1]

    last_day_index = int(df["day_index"].iloc[-1])
    last_date = df["date"].iloc[-1]
    mean_revenue = df["revenue"].mean() if df["revenue"].mean() != 0 else 1.0

    forecast = []
    for i in range(1, request.days_ahead + 1):
        day_index = last_day_index + i
        predicted = max(0.0, slope * day_index + intercept)
        forecast.append(ForecastPoint(
            date=(last_date + pd.Timedelta(days=i)).strftime("%Y-%m-%d"),
            predicted_revenue=round(float(predicted), 2),
        ))

    daily_growth_rate = round(float(slope / mean_revenue), 4)
    if daily_growth_rate > 0.01:
        trend = "increasing"
    elif daily_growth_rate < -0.01:
        trend = "decreasing"
    else:
        trend = "stable"

    return ForecastResponse(forecast=forecast, trend=trend, daily_growth_rate=daily_growth_rate)


@app.get("/health")
def health():
    return {"status": "ok"}