package com.hitachi.mcs.dto;

import lombok.Data;
import java.math.BigDecimal;

@Data
public class ReportResponse {
    private Long merchantId;
    private String merchantName;
    private String period;
    private Long totalSettledTransactions;
    private BigDecimal totalRevenue;
}