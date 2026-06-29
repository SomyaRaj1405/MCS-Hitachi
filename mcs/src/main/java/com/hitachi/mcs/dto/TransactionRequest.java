package com.hitachi.mcs.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

@Data
public class TransactionRequest {

    @NotNull(message = "Bill ID is required")
    private Long billId;

    @NotNull(message = "Transaction ID is required")
    private Long transactionId;

    @NotBlank(message = "Payment method is required")
    @Pattern(
            regexp = "UPI|CARD|NETBANKING",
            message = "Payment method must be UPI, CARD, or NETBANKING"
    )
    private String paymentMethod;
}