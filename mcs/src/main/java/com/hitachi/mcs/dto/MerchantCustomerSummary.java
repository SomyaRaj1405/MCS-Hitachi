package com.hitachi.mcs.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@AllArgsConstructor
public class MerchantCustomerSummary {
    private Long customerId;
    private String name;
    private String email;
    private String phone;
    private Boolean active;
    private long totalBills;
    private long paidBills;
    private long pendingBills;
    private long failedBills;
    private long refundedBills;
    private BigDecimal totalPaid;
    private BigDecimal outstandingAmount;
    private BigDecimal refundedAmount;
    private LocalDateTime lastPaymentAt;
}
