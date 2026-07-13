package com.hitachi.mcs.kafka;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.net.URI;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Tracks open WebSocket sessions keyed by merchantId and pushes
 * transaction events only to the dashboards of the merchant they
 * belong to.
 *
 * Connect with: ws://<host>:8080/ws/live-feed?merchantId=123
 */
@Component
public class LiveFeedWebSocketHandler extends TextWebSocketHandler {

    private static final Logger log = LoggerFactory.getLogger(LiveFeedWebSocketHandler.class);
    private static final Pattern MERCHANT_ID_PATTERN = Pattern.compile("merchantId=(\\d+)");

    // merchantId -> list of open sessions for that merchant
    private final Map<Long, List<WebSocketSession>> sessionsByMerchant = new ConcurrentHashMap<>();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        Long merchantId = extractMerchantId(session);
        if (merchantId == null) {
            log.warn("Live feed connection rejected: missing merchantId query param");
            closeQuietly(session, CloseStatus.BAD_DATA);
            return;
        }

        sessionsByMerchant
                .computeIfAbsent(merchantId, id -> new CopyOnWriteArrayList<>())
                .add(session);
        session.getAttributes().put("merchantId", merchantId);

        log.info("Live feed connected: merchantId={} sessionId={}", merchantId, session.getId());
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        Long merchantId = (Long) session.getAttributes().get("merchantId");
        if (merchantId != null) {
            List<WebSocketSession> sessions = sessionsByMerchant.get(merchantId);
            if (sessions != null) {
                sessions.remove(session);
                if (sessions.isEmpty()) {
                    sessionsByMerchant.remove(merchantId);
                }
            }
        }
        log.info("Live feed disconnected: sessionId={} status={}", session.getId(), status);
    }

    /**
     * Called by LiveFeedConsumer whenever a new TransactionEvent arrives
     * from Kafka. Sends the event only to sessions belonging to the
     * merchant the transaction happened for.
     */
    public void broadcastToMerchant(Long merchantId, TransactionEvent event) {
        List<WebSocketSession> sessions = sessionsByMerchant.get(merchantId);
        if (sessions == null || sessions.isEmpty()) {
            return; // no dashboard currently open for this merchant — nothing to do
        }

        try {
            String payload = objectMapper.writeValueAsString(event);
            TextMessage message = new TextMessage(payload);

            for (WebSocketSession session : sessions) {
                if (session.isOpen()) {
                    session.sendMessage(message);
                }
            }
        } catch (IOException e) {
            log.error("Failed to broadcast live feed event for merchantId={}: {}",
                    merchantId, e.getMessage());
        }
    }

    private Long extractMerchantId(WebSocketSession session) {
        URI uri = session.getUri();
        if (uri == null || uri.getQuery() == null) return null;

        Matcher matcher = MERCHANT_ID_PATTERN.matcher(uri.getQuery());
        if (matcher.find()) {
            try {
                return Long.parseLong(matcher.group(1));
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }

    private void closeQuietly(WebSocketSession session, CloseStatus status) {
        try {
            session.close(status);
        } catch (IOException ignored) {
            // session already closing — nothing more to do
        }
    }
}