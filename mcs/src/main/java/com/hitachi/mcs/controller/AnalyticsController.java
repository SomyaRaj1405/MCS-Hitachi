package com.hitachi.mcs.controller;

import com.hitachi.mcs.dto.ForecastResponse;
import com.hitachi.mcs.service.AnalyticsService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/analytics")
public class AnalyticsController {

    private final AnalyticsService analyticsService;

    public AnalyticsController(AnalyticsService analyticsService) {
        this.analyticsService = analyticsService;
    }

    /**
     * Returns a predicted revenue trend for the merchant dashboard chart.
     *
     * GET /analytics/revenue-forecast?historyDays=30&daysAhead=7
     */
    @GetMapping("/revenue-forecast")
    public ForecastResponse getRevenueForecast(
            @RequestParam(defaultValue = "30") int historyDays,
            @RequestParam(defaultValue = "7") int daysAhead) {
        return analyticsService.getRevenueForecast(historyDays, daysAhead);
    }
}