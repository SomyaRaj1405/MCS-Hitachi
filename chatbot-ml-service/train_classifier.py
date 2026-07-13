"""
MCS Chatbot - Intent Classifier Training Script
-------------------------------------------------
Trains a TF-IDF + Logistic Regression classifier on labeled merchant
support queries, evaluates it on a held-out test split, and saves:
  - model.joblib          (trained pipeline: vectorizer + classifier)
  - confusion_matrix.png  (for project deliverables / demo slides)
  - classification_report.txt (precision/recall/f1 per intent)

Usage:
    python train_classifier.py
"""

import pandas as pd
import joblib
import matplotlib
matplotlib.use("Agg")  # no display needed, just save to file
import matplotlib.pyplot as plt

from sklearn.model_selection import train_test_split
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.metrics import (
    classification_report,
    confusion_matrix,
    accuracy_score,
    ConfusionMatrixDisplay,
)

DATA_PATH = "intent_training_data.csv"
MODEL_PATH = "model.joblib"
CM_PATH = "confusion_matrix.png"
REPORT_PATH = "classification_report.txt"

RANDOM_STATE = 42
TEST_SIZE = 0.2  # 80/20 split; with ~118 examples this is a small test set,
                  # so treat the accuracy number as indicative, not definitive.


def main():
    # 1. Load data
    df = pd.read_csv(DATA_PATH)
    df = df.dropna()
    print(f"Loaded {len(df)} examples across {df['intent'].nunique()} intents.")
    print(df["intent"].value_counts(), "\n")

    X = df["text"]
    y = df["intent"]

    # 2. Train/test split (stratified so small classes are represented in both)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=TEST_SIZE, random_state=RANDOM_STATE, stratify=y
    )

    # 3. Build pipeline: TF-IDF vectorizer -> Logistic Regression
    pipeline = Pipeline([
        ("tfidf", TfidfVectorizer(
            lowercase=True,
            ngram_range=(1, 2),   # unigrams + bigrams help with short queries
            min_df=1,
            stop_words="english",
        )),
        ("clf", LogisticRegression(
            max_iter=1000,
            class_weight="balanced",  # helps with the slightly uneven class sizes
            random_state=RANDOM_STATE,
        )),
    ])

    # 4. Train
    pipeline.fit(X_train, y_train)

    # 5. Evaluate
    y_pred = pipeline.predict(X_test)
    acc = accuracy_score(y_test, y_pred)
    report = classification_report(y_test, y_pred)

    print(f"Test accuracy: {acc:.2%}\n")
    print(report)

    with open(REPORT_PATH, "w") as f:
        f.write(f"Test accuracy: {acc:.2%}\n\n")
        f.write(report)

    # 6. Confusion matrix plot
    labels = sorted(y.unique())
    cm = confusion_matrix(y_test, y_pred, labels=labels)
    disp = ConfusionMatrixDisplay(confusion_matrix=cm, display_labels=labels)
    fig, ax = plt.subplots(figsize=(8, 7))
    disp.plot(ax=ax, xticks_rotation=45, cmap="Reds", colorbar=False)
    plt.title("Intent Classifier - Confusion Matrix")
    plt.tight_layout()
    plt.savefig(CM_PATH, dpi=150)
    print(f"Saved confusion matrix to {CM_PATH}")

    # 7. Save the trained pipeline (vectorizer + model together)
    joblib.dump(pipeline, MODEL_PATH)
    print(f"Saved trained model to {MODEL_PATH}")

    # 8. Quick sanity check with a few example queries
    print("\n--- Sanity check ---")
    samples = [
        "show me my failed transactions today",
        "I want a pdf of this month's sales",
        "how do I get my money back for a bad order",
        "what is my merchant id",
        "do you support international cards",
        "hey",
    ]
    for s in samples:
        pred = pipeline.predict([s])[0]
        proba = pipeline.predict_proba([s]).max()
        print(f"  '{s}' -> {pred} (confidence: {proba:.2f})")


if __name__ == "__main__":
    main()
