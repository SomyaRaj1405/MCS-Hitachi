package com.hitachi.mcs.kafka;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

/**
 * Publishes a TransactionEvent to Kafka right after a payment is
 * committed to the database. This call is fire-and-forget from the
 * caller's perspective — it does not block the HTTP response.
 *
 * Inject this into your existing PaymentController / PaymentService
 * and call publishTransactionCompleted(...) right after you save
 * the transaction row.
 */
@Service
public class TransactionEventProducer {

    private static final Logger log = LoggerFactory.getLogger(TransactionEventProducer.class);

    private final KafkaTemplate<String, TransactionEvent> kafkaTemplate;

    @Value("${mcs.kafka.topic.transaction-completed}")
    private String transactionCompletedTopic;

    public TransactionEventProducer(KafkaTemplate<String, TransactionEvent> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    public void publishTransactionCompleted(TransactionEvent event) {
        log.info("Publishing transaction event: {}", event.getTransactionId());

        kafkaTemplate.send(transactionCompletedTopic, event.getTransactionId(), event)
                .whenComplete((result, ex) -> {
                    if (ex != null) {
                        // Even if Kafka is briefly unavailable, the payment itself
                        // already succeeded and was committed to Postgres — this
                        // only affects the downstream async consumers.
                        log.error("Failed to publish transaction event {}: {}",
                                event.getTransactionId(), ex.getMessage());
                    } else {
                        log.info("Transaction event {} published to partition {}",
                                event.getTransactionId(),
                                result.getRecordMetadata().partition());
                    }
                });
    }
}