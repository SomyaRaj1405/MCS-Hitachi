package com.hitachi.mcs.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

@Data
public class InitiateTransactionRequest {

    @NotNull(message = "Bill ID is required")
    private Long billId;

    @NotBlank(message = "Payment method is required")
    @Pattern(regexp = "UPI|CARD|NETBANKING", message = "Payment method must be UPI, CARD, or NETBANKING")
    private String paymentMethod;
}