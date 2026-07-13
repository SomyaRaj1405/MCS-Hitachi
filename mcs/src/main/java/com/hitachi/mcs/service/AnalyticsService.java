package com.hitachi.mcs.service;

import com.hitachi.mcs.dto.ForecastRequest;
import com.hitachi.mcs.dto.ForecastResponse;
import com.hitachi.mcs.repository.TransactionRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.sql.Date;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
public class AnalyticsService {

    private final TransactionRepository transactionRepository;
    private final RestTemplate mlServiceRestTemplate;

    @Value("${mcs.ml-service.base-url}")
    private String mlServiceBaseUrl;

    public AnalyticsService(TransactionRepository transactionRepository,
                             RestTemplate mlServiceRestTemplate) {
        this.transactionRepository = transactionRepository;
        this.mlServiceRestTemplate = mlServiceRestTemplate;
    }

    public ForecastResponse getRevenueForecast(int historyDays, int daysAhead) {
        LocalDateTime since = LocalDateTime.now().minusDays(historyDays);
        List<Object[]> rows = transactionRepository.findDailyRevenueSince(since);

        List<ForecastRequest.RevenuePoint> history = new ArrayList<>();
        for (Object[] row : rows) {
            // row[0] is a java.sql.Date (from the DATE() function), row[1] is the summed amount
            String dateStr = row[0].toString(); // yyyy-MM-dd
            double revenue = ((Number) row[1]).doubleValue();
            history.add(new ForecastRequest.RevenuePoint(dateStr, revenue));
        }

        ForecastRequest request = new ForecastRequest(history, daysAhead);

        return mlServiceRestTemplate.postForObject(
                mlServiceBaseUrl + "/predict/revenue-forecast",
                request,
                ForecastResponse.class
        );
    }
}