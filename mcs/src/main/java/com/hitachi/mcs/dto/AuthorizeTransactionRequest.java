package com.hitachi.mcs.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class AuthorizeTransactionRequest {

    @NotNull(message = "Transaction ID is required")
    private Long transactionId;
}