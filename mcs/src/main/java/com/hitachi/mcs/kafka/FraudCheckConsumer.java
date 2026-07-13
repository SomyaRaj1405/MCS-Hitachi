package com.hitachi.mcs.kafka;

import com.hitachi.mcs.repository.TransactionRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.time.LocalDateTime;
import java.time.ZoneId;

/**
 * Flags potentially risky transactions after the fact, without blocking
 * the original payment. Calls the separate MCS ML Service (Python/FastAPI,
 * localhost:8000) which runs a trained Isolation Forest anomaly-detection
 * model, rather than a hardcoded amount threshold.
 */
@Component
public class FraudCheckConsumer {

    private static final Logger log = LoggerFactory.getLogger(FraudCheckConsumer.class);

    private final TransactionRepository transactionRepository;
    private final RestTemplate mlServiceRestTemplate;

    @Value("${mcs.ml-service.base-url}")
    private String mlServiceBaseUrl;

    public FraudCheckConsumer(TransactionRepository transactionRepository,
                               RestTemplate mlServiceRestTemplate) {
        this.transactionRepository = transactionRepository;
        this.mlServiceRestTemplate = mlServiceRestTemplate;
    }

    @KafkaListener(
            topics = "${mcs.kafka.topic.transaction-completed}",
            groupId = "mcs-fraud-checker"
    )
    public void onTransactionCompleted(TransactionEvent event) {
        try {
            int hourOfDay = event.getTimestamp()
                    .atZone(ZoneId.systemDefault())
                    .getHour();

            long customerTxnCount24h = transactionRepository.countByBillCustomerIdAndCreatedAtAfter(
                    event.getCustomerId(), LocalDateTime.now().minusHours(24));

            Double merchantAvg = transactionRepository.findAverageAmountByMerchantId(event.getMerchantId());
            double merchantAvgAmount = (merchantAvg != null) ? merchantAvg : event.getAmount().doubleValue();

            FraudCheckRequest request = new FraudCheckRequest(
                    event.getAmount().doubleValue(),
                    hourOfDay,
                    customerTxnCount24h,
                    merchantAvgAmount
            );

            FraudCheckResponse response = mlServiceRestTemplate.postForObject(
                    mlServiceBaseUrl + "/predict/fraud",
                    request,
                    FraudCheckResponse.class
            );

            if (response != null && response.isFlagged()) {
                log.warn("[FraudCheckConsumer] Transaction {} FLAGGED — risk_score={}, amount={}",
                        event.getTransactionId(), response.getRiskScore(), event.getAmount());
                // Example future step: write to a "flagged_transactions" table,
                // or notify a merchant/admin dashboard in real time.
            } else if (response != null) {
                log.info("[FraudCheckConsumer] Transaction {} passed risk check — risk_score={}",
                        event.getTransactionId(), response.getRiskScore());
            }

        } catch (Exception e) {
            // ML service being briefly unavailable should never break transaction
            // processing — this consumer only adds a risk signal, it doesn't
            // gate the payment itself.
            log.error("[FraudCheckConsumer] Could not reach ML service for transaction {}: {}",
                    event.getTransactionId(), e.getMessage());
        }
    }
}