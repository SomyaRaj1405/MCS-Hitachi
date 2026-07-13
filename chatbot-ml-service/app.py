"""
MCS Chatbot - Intent Classification Microservice
---------------------------------------------------
Exposes a single endpoint that Spring Boot calls to classify a merchant's
chatbot query into one of six intents. Spring Boot then decides what to
do with that intent (query the DB, call the LLM, or fall back to the
existing rule-based matcher on low confidence).

Run locally:
    uvicorn app:app --host 0.0.0.0 --port 8001 --reload

Then visit http://localhost:8001/docs for interactive API docs.
"""

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
import joblib
import os

MODEL_PATH = "model.joblib"

# Below this confidence, Spring Boot should treat the classification as
# unreliable and fall back to the existing rule-based intent matcher.
CONFIDENCE_THRESHOLD = 0.35

app = FastAPI(
    title="MCS Chatbot Intent Classifier",
    description="Classifies merchant chatbot queries into support intents.",
    version="1.0.0",
)

_pipeline = None


@app.on_event("startup")
def load_model():
    global _pipeline
    if not os.path.exists(MODEL_PATH):
        raise RuntimeError(
            f"{MODEL_PATH} not found. Run train_classifier.py first."
        )
    _pipeline = joblib.load(MODEL_PATH)


class ClassifyRequest(BaseModel):
    text: str = Field(..., min_length=1, description="The merchant's chat message")


class ClassifyResponse(BaseModel):
    intent: str
    confidence: float
    reliable: bool  # False if below CONFIDENCE_THRESHOLD -> Spring Boot should fall back
    all_scores: dict[str, float]


@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": _pipeline is not None}


@app.post("/classify", response_model=ClassifyResponse)
def classify(req: ClassifyRequest):
    if _pipeline is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    text = req.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="text must not be empty")

    proba = _pipeline.predict_proba([text])[0]
    classes = _pipeline.classes_
    scores = {cls: round(float(p), 4) for cls, p in zip(classes, proba)}

    best_idx = proba.argmax()
    intent = classes[best_idx]
    confidence = float(proba[best_idx])

    return ClassifyResponse(
        intent=intent,
        confidence=round(confidence, 4),
        reliable=confidence >= CONFIDENCE_THRESHOLD,
        all_scores=scores,
    )
