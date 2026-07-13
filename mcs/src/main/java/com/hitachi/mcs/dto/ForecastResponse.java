package com.hitachi.mcs.dto;

import java.util.List;

public class ForecastResponse {
    private List<ForecastPoint> forecast;
    private String trend;
    private double dailyGrowthRate;

    public List<ForecastPoint> getForecast() { return forecast; }
    public void setForecast(List<ForecastPoint> forecast) { this.forecast = forecast; }

    public String getTrend() { return trend; }
    public void setTrend(String trend) { this.trend = trend; }

    public double getDailyGrowthRate() { return dailyGrowthRate; }
    public void setDailyGrowthRate(double dailyGrowthRate) { this.dailyGrowthRate = dailyGrowthRate; }

    public static class ForecastPoint {
        private String date;
        private double predictedRevenue;

        public String getDate() { return date; }
        public void setDate(String date) { this.date = date; }

        public double getPredictedRevenue() { return predictedRevenue; }
        public void setPredictedRevenue(double predictedRevenue) { this.predictedRevenue = predictedRevenue; }
    }
}