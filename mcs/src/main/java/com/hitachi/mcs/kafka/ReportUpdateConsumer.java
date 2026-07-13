package com.hitachi.mcs.kafka;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

/**
 * Reacts to completed transactions by updating report aggregates
 * (e.g. daily totals used by the merchant dashboard fl_chart views).
 *
 * This is intentionally separate from the payment write path: if
 * report recomputation is slow, it never delays the customer's
 * payment confirmation.
 *
 * TODO: wire in your actual ReportService/repository here.
 */
@Component
public class ReportUpdateConsumer {

    private static final Logger log = LoggerFactory.getLogger(ReportUpdateConsumer.class);

    @KafkaListener(
            topics = "${mcs.kafka.topic.transaction-completed}",
            groupId = "mcs-report-updater"
    )
    public void onTransactionCompleted(TransactionEvent event) {
        log.info("[ReportUpdateConsumer] Updating report aggregates for merchant {} — amount {}",
                event.getMerchantId(), event.getAmount());

        // Example integration point:
        // reportService.incrementDailyTotal(event.getMerchantId(), event.getAmount());
    }
}