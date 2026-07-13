package com.hitachi.mcs.kafka;

public class FraudCheckResponse {
    private boolean flagged;
    private double riskScore;
    private double rawAnomalyScore;

    public boolean isFlagged() { return flagged; }
    public void setFlagged(boolean flagged) { this.flagged = flagged; }

    public double getRiskScore() { return riskScore; }
    public void setRiskScore(double riskScore) { this.riskScore = riskScore; }

    public double getRawAnomalyScore() { return rawAnomalyScore; }
    public void setRawAnomalyScore(double rawAnomalyScore) { this.rawAnomalyScore = rawAnomalyScore; }
}