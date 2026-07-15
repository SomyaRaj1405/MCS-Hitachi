package com.hitachi.mcs.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;

@Service
public class AuthorizationDecisionService {
    private final SecureRandom random = new SecureRandom();
    private final double successRate;

    public AuthorizationDecisionService(
            @Value("${mcs.authorization.success-rate:0.90}") double successRate) {
        if (successRate < 0 || successRate > 1) {
            throw new IllegalArgumentException("Authorization success rate must be between 0 and 1");
        }
        this.successRate = successRate;
    }

    public boolean approve() {
        return random.nextDouble() < successRate;
    }
}
