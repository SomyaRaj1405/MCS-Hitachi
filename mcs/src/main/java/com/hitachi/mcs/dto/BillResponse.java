package com.hitachi.mcs.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
public class BillResponse {
    private Long id;
    private Long merchantId;
    private String merchantName;
    private Long customerId;
    private String customerName;
    private BigDecimal amount;
    private String description;
    private String status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}