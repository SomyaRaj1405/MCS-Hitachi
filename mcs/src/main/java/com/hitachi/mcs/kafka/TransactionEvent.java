package com.hitachi.mcs.kafka;

import java.io.Serializable;
import java.math.BigDecimal;
import java.time.Instant;

/**
 * Event published to the "transaction-completed" Kafka topic
 * the moment a payment is successfully processed.
 *
 * Consumers (report updater, audit logger, fraud checker) each
 * react to this independently and asynchronously — none of them
 * block the original payment response to the customer.
 */
public class TransactionEvent implements Serializable {

    private String transactionId;
    private Long merchantId;
    private Long customerId;
    private BigDecimal amount;
    private String status;       // e.g. SUCCESS, FAILED
    private String paymentMode;  // e.g. UPI, CARD, WALLET
    private Instant timestamp;

    public TransactionEvent() {
        // required no-arg constructor for JSON deserialization
    }

    public TransactionEvent(String transactionId, Long merchantId, Long customerId,
                             BigDecimal amount, String status, String paymentMode, Instant timestamp) {
        this.transactionId = transactionId;
        this.merchantId = merchantId;
        this.customerId = customerId;
        this.amount = amount;
        this.status = status;
        this.paymentMode = paymentMode;
        this.timestamp = timestamp;
    }

    public String getTransactionId() { return transactionId; }
    public void setTransactionId(String transactionId) { this.transactionId = transactionId; }

    public Long getMerchantId() { return merchantId; }
    public void setMerchantId(Long merchantId) { this.merchantId = merchantId; }

    public Long getCustomerId() { return customerId; }
    public void setCustomerId(Long customerId) { this.customerId = customerId; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getPaymentMode() { return paymentMode; }
    public void setPaymentMode(String paymentMode) { this.paymentMode = paymentMode; }

    public Instant getTimestamp() { return timestamp; }
    public void setTimestamp(Instant timestamp) { this.timestamp = timestamp; }

    @Override
    public String toString() {
        return "TransactionEvent{" +
                "transactionId='" + transactionId + '\'' +
                ", merchantId=" + merchantId +
                ", customerId=" + customerId +
                ", amount=" + amount +
                ", status='" + status + '\'' +
                ", paymentMode='" + paymentMode + '\'' +
                ", timestamp=" + timestamp +
                '}';
    }
}