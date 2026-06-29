package com.hitachi.mcs.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
public class TransactionResponse {
    private Long id;
    private Long billId;
    private BigDecimal amount;
    private String paymentMethod;
    private String status;
    private String billStatus;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}