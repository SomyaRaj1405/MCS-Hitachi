package com.hitachi.mcs.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

public class ForecastRequest {

    @JsonProperty("history")
    private List<RevenuePoint> history;

    @JsonProperty("days_ahead")
    private int daysAhead;

    public ForecastRequest() {}

    public ForecastRequest(List<RevenuePoint> history, int daysAhead) {
        this.history = history;
        this.daysAhead = daysAhead;
    }

    public List<RevenuePoint> getHistory() { return history; }
    public void setHistory(List<RevenuePoint> history) { this.history = history; }

    public int getDaysAhead() { return daysAhead; }
    public void setDaysAhead(int daysAhead) { this.daysAhead = daysAhead; }

    public static class RevenuePoint {
        private String date;
        private double revenue;

        public RevenuePoint() {}

        public RevenuePoint(String date, double revenue) {
            this.date = date;
            this.revenue = revenue;
        }

        public String getDate() { return date; }
        public void setDate(String date) { this.date = date; }

        public double getRevenue() { return revenue; }
        public void setRevenue(double revenue) { this.revenue = revenue; }
    }
}