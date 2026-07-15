package com.hitachi.mcs.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.util.List;

@Data
@AllArgsConstructor
public class MerchantCustomerPage {
    private List<MerchantCustomerSummary> content;
    private long totalElements;
    private int totalPages;
    private int number;
    private int size;
}
