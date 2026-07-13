"""
train_fraud_model.py

Generates synthetic transaction data (since MCS is a simulation and has no
real labeled fraud data) and trains an Isolation Forest model — an
unsupervised anomaly detection algorithm well-suited to fraud detection,
since real fraud is rare and rarely labeled in advance.

Features used (deliberately simple, matching what MCS can realistically
provide at settlement time):
  - amount: transaction amount
  - hour_of_day: hour the transaction occurred (0-23)
  - customer_txn_count_24h: how many transactions this customer made
    in the last 24 hours (velocity check — a classic fraud signal)
  - amount_deviation_from_merchant_avg: how far this amount is from
    the merchant's typical transaction size

Run this once to produce fraud_model.joblib, which app.py loads at startup.
"""

import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
import joblib

np.random.seed(42)

N_NORMAL = 4000
N_SUSPICIOUS = 200  # injected anomalies to help the model learn the boundary

# --- Normal transaction patterns ---
normal_amount = np.random.gamma(shape=2.0, scale=400, size=N_NORMAL)  # most transactions modest, right-skewed
hour_weights = np.array([0.01,0.01,0.01,0.01,0.01,0.02,0.03,0.05,
                          0.06,0.07,0.07,0.07,0.07,0.06,0.06,0.06,
                          0.06,0.06,0.05,0.05,0.04,0.03,0.02,0.02])
hour_weights = hour_weights / hour_weights.sum()
normal_hour = np.random.choice(range(24), size=N_NORMAL, p=hour_weights)
normal_velocity = np.random.poisson(1.5, size=N_NORMAL)  # most customers transact rarely in a day
normal_deviation = np.random.normal(0, 1, size=N_NORMAL)  # close to merchant's typical amount

# --- Suspicious/anomalous patterns (unusually large, odd hours, high velocity, big deviation) ---
sus_amount = np.random.gamma(shape=2.0, scale=400, size=N_SUSPICIOUS) * np.random.uniform(5, 15, N_SUSPICIOUS)
sus_hour_weights = np.array([0.08]*6 + [0.02]*12 + [0.08]*6)
sus_hour_weights = sus_hour_weights / sus_hour_weights.sum()
sus_hour = np.random.choice(range(24), size=N_SUSPICIOUS, p=sus_hour_weights)
sus_velocity = np.random.poisson(8, size=N_SUSPICIOUS)  # rapid repeated transactions
sus_deviation = np.random.normal(0, 1, size=N_SUSPICIOUS) * np.random.uniform(4, 8, N_SUSPICIOUS)

amount = np.concatenate([normal_amount, sus_amount])
hour_of_day = np.concatenate([normal_hour, sus_hour])
customer_txn_count_24h = np.concatenate([normal_velocity, sus_velocity])
amount_deviation_from_merchant_avg = np.concatenate([normal_deviation, sus_deviation])

df = pd.DataFrame({
    "amount": amount,
    "hour_of_day": hour_of_day,
    "customer_txn_count_24h": customer_txn_count_24h,
    "amount_deviation_from_merchant_avg": amount_deviation_from_merchant_avg,
})

features = ["amount", "hour_of_day", "customer_txn_count_24h", "amount_deviation_from_merchant_avg"]

# contamination ~= expected proportion of anomalies in real-world traffic
model = IsolationForest(
    n_estimators=200,
    contamination=0.05,
    random_state=42,
)
model.fit(df[features])

joblib.dump({"model": model, "features": features}, "fraud_model.joblib")

print("Model trained and saved to fraud_model.joblib")
print(f"Training rows: {len(df)}")

# Quick sanity check
sample_normal = pd.DataFrame([{
    "amount": 500, "hour_of_day": 14,
    "customer_txn_count_24h": 1, "amount_deviation_from_merchant_avg": 0.1
}])
sample_suspicious = pd.DataFrame([{
    "amount": 45000, "hour_of_day": 3,
    "customer_txn_count_24h": 12, "amount_deviation_from_merchant_avg": 6.5
}])

for name, sample in [("normal-looking", sample_normal), ("suspicious-looking", sample_suspicious)]:
    score = model.decision_function(sample[features])[0]
    pred = model.predict(sample[features])[0]
    print(f"{name}: anomaly_score={score:.3f}, prediction={'FLAGGED' if pred == -1 else 'OK'}")