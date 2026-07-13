package com.hitachi.mcs.config;

import com.hitachi.mcs.kafka.LiveFeedWebSocketHandler;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

/**
 * Registers the WebSocket endpoint that pushes live transaction events
 * to connected merchant dashboards.
 *
 * Endpoint: ws://<host>:8080/ws/live-feed?merchantId=<id>
 *
 * setAllowedOrigins("*") is used here because the Flutter app is not
 * served from the same origin as the Spring Boot backend during
 * development. Tighten this before any real production deployment.
 */
@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {

    private final LiveFeedWebSocketHandler liveFeedWebSocketHandler;

    public WebSocketConfig(LiveFeedWebSocketHandler liveFeedWebSocketHandler) {
        this.liveFeedWebSocketHandler = liveFeedWebSocketHandler;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(liveFeedWebSocketHandler, "/ws/live-feed")
                .setAllowedOrigins("*");
    }
}