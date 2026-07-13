package com.hitachi.mcs.kafka;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

/**
 * Pushes every completed transaction to any merchant dashboard that
 * currently has a live feed WebSocket open.
 *
 * Runs in its own consumer group ("mcs-live-feed") so a slow or
 * disconnected dashboard never affects the audit logger, report
 * updater, or fraud checker consumers — each tracks its own Kafka
 * offset independently.
 */
@Component
public class LiveFeedConsumer {

    private static final Logger log = LoggerFactory.getLogger(LiveFeedConsumer.class);

    private final LiveFeedWebSocketHandler webSocketHandler;

    public LiveFeedConsumer(LiveFeedWebSocketHandler webSocketHandler) {
        this.webSocketHandler = webSocketHandler;
    }

    @KafkaListener(
            topics = "${mcs.kafka.topic.transaction-completed}",
            groupId = "mcs-live-feed"
    )
    public void onTransactionCompleted(TransactionEvent event) {
        log.info("[LiveFeedConsumer] Broadcasting txn={} to merchantId={}",
                event.getTransactionId(), event.getMerchantId());

        if (event.getMerchantId() != null) {
            webSocketHandler.broadcastToMerchant(event.getMerchantId(), event);
        }
    }
}