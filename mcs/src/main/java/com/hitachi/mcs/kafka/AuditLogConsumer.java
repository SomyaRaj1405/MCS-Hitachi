package com.hitachi.mcs.kafka;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

/**
 * Writes an immutable audit trail entry for every completed transaction.
 * Runs in its own consumer group so it processes independently of the
 * report updater and fraud checker — one being slow or failing does
 * not affect the others (each has its own offset tracking in Kafka).
 *
 * TODO: wire in your actual AuditLogRepository here.
 */
@Component
public class AuditLogConsumer {

    private static final Logger log = LoggerFactory.getLogger(AuditLogConsumer.class);

    @KafkaListener(
            topics = "${mcs.kafka.topic.transaction-completed}",
            groupId = "mcs-audit-logger"
    )
    public void onTransactionCompleted(TransactionEvent event) {
        log.info("[AuditLogConsumer] Logging audit entry: txn={} status={} at {}",
                event.getTransactionId(), event.getStatus(), event.getTimestamp());

        // Example integration point:
        // auditLogRepository.save(new AuditLog(event.getTransactionId(),
        //         "TRANSACTION_COMPLETED", event.getTimestamp()));
    }
}