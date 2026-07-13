package com.hitachi.mcs.config;

import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

import java.time.Duration;

/**
 * Provides a RestTemplate used to call the separate MCS ML Service
 * (Python/FastAPI, running on localhost:8000) for fraud scoring and
 * revenue forecasting.
 */
@Configuration
public class MlServiceConfig {

    @Bean
    public RestTemplate mlServiceRestTemplate(RestTemplateBuilder builder) {
        return builder
                .setConnectTimeout(Duration.ofSeconds(2))
                .setReadTimeout(Duration.ofSeconds(3))
                .build();
    }
}