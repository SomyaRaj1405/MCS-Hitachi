# MCS ML Service

A small Python/FastAPI microservice that adds two predictive-analytics
capabilities to MCS, sitting alongside your Spring Boot backend:

1. **Fraud risk scoring** (`POST /predict/fraud`) — an Isolation Forest
   model (unsupervised anomaly detection) trained on synthetic transaction
   patterns, replacing the hardcoded amount threshold in `FraudCheckConsumer`.
2. **Revenue forecasting** (`POST /predict/revenue-forecast`) — a simple,
   explainable linear-trend forecast over your historical daily revenue,
   for a predictive-analytics chart on the merchant dashboard.

This runs as a **separate process** from your Spring Boot app — Java calls
it over plain HTTP, the same way it already talks to Kafka as a separate
process. Nothing about your existing backend/DB is touched.

## Setup

```bash
cd ml-service
pip install -r requirements.txt --break-system-packages
python train_fraud_model.py      # generates fraud_model.joblib (run once)
uvicorn app:app --reload --port 8000
```

Verify it's running:
```bash
curl http://localhost:8000/health
```

## Endpoints

### POST /predict/fraud
```json
// request
{
  "amount": 48000,
  "hour_of_day": 3,
  "customer_txn_count_24h": 15,
  "merchant_avg_amount": 500
}
// response
{
  "flagged": true,
  "risk_score": 0.91,
  "raw_anomaly_score": -0.24
}
```

### POST /predict/revenue-forecast
```json
// request
{
  "history": [
    {"date": "2026-07-01", "revenue": 1000},
    {"date": "2026-07-02", "revenue": 1100}
  ],
  "days_ahead": 7
}
// response
{
  "forecast": [{"date": "2026-07-03", "predicted_revenue": 1180.5}, ...],
  "trend": "increasing",
  "daily_growth_rate": 0.05
}
```

## Next: wiring into Spring Boot

To call `/predict/fraud` from `FraudCheckConsumer`, we need two data points
your Java code doesn't currently have to hand: the customer's transaction
count in the last 24 hours, and the merchant's average transaction amount.
Both require small repository queries against your actual schema — send me
`TransactionRepository.java` (and `Transaction.java`/`Bill.java` if the
field names aren't obvious from the repository) and I'll write the exact
queries and the updated `FraudCheckConsumer` + a new `AnalyticsController`
for the revenue forecast, matching your real column/field names.