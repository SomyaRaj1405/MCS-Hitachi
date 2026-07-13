package com.hitachi.mcs.ai;

import com.fasterxml.jackson.annotation.JsonProperty;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

/**
 * Calls the Python FastAPI intent-classifier microservice (ml-service/app.py)
 * to classify chat messages the rule-based IntentParserService couldn't
 * confidently handle (i.e. it returned ChatIntent.UNKNOWN).
 *
 * This is a second-opinion layer, not a replacement: it only runs when the
 * fast, deterministic rule-based parser has already given up on a message.
 *
 * If the Python service is unreachable or errors out, classify() returns a
 * result with reliable=false so callers fall back safely instead of
 * throwing and breaking the chat response.
 */
@Service
public class IntentClassifierClient {

    private final RestTemplate restTemplate = new RestTemplate();

    @Value("${chatbot.classifier.url:http://localhost:8001}")
    private String classifierBaseUrl;

    public ClassificationResult classify(String text) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            Map<String, String> body = Map.of("text", text);
            HttpEntity<Map<String, String>> request = new HttpEntity<>(body, headers);

            ClassificationResult result = restTemplate.postForObject(
                    classifierBaseUrl + "/classify",
                    request,
                    ClassificationResult.class
            );

            return result != null ? result : ClassificationResult.unreliableFallback();

        } catch (RestClientException e) {
            // Python service down, unreachable, or timed out — degrade gracefully.
            // Caller should treat this the same as a low-confidence classification.
            return ClassificationResult.unreliableFallback();
        }
    }

    /**
     * Mirrors the JSON shape returned by /classify in app.py:
     * { "intent": "...", "confidence": 0.83, "reliable": true, "all_scores": {...} }
     */
    public static class ClassificationResult {
        private String intent;
        private double confidence;
        private boolean reliable;

        @JsonProperty("all_scores")
        private Map<String, Double> allScores;

        public String getIntent() { return intent; }
        public void setIntent(String intent) { this.intent = intent; }

        public double getConfidence() { return confidence; }
        public void setConfidence(double confidence) { this.confidence = confidence; }

        public boolean isReliable() { return reliable; }
        public void setReliable(boolean reliable) { this.reliable = reliable; }

        public Map<String, Double> getAllScores() { return allScores; }
        public void setAllScores(Map<String, Double> allScores) { this.allScores = allScores; }

        public static ClassificationResult unreliableFallback() {
            ClassificationResult r = new ClassificationResult();
            r.intent = "unknown";
            r.confidence = 0.0;
            r.reliable = false;
            return r;
        }
    }
}