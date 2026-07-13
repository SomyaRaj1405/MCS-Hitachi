package com.hitachi.mcs.kafka;

import org.apache.kafka.clients.admin.NewTopic;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.TopicBuilder;

@Configuration
public class KafkaTopicConfig {

    @Value("${mcs.kafka.topic.transaction-completed}")
    private String transactionCompletedTopic;

    @Bean
    public NewTopic transactionCompletedTopic() {
        return TopicBuilder.name(transactionCompletedTopic)
                .partitions(3)
                .replicas(1)
                .build();
    }
}