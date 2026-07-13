package com.hitachi.mcs.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
public class TransactionResponse {
    private Long id;
    private Long billId;
    private Long merchantId;
    private String merchantName;
    private Long customerId;
    private String customerName;
    private BigDecimal amount;
    private String description;
    private String paymentMethod;
    private String status;
    private String billStatus;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
