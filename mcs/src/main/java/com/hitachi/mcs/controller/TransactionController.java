package com.hitachi.mcs.controller;

import com.hitachi.mcs.dto.AuthorizeTransactionRequest;
import com.hitachi.mcs.dto.InitiateTransactionRequest;
import com.hitachi.mcs.dto.SettleTransactionRequest;
import com.hitachi.mcs.dto.TransactionResponse;
import com.hitachi.mcs.service.TransactionService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/transactions")
public class TransactionController {

    private final TransactionService transactionService;

    public TransactionController(TransactionService transactionService) {
        this.transactionService = transactionService;
    }

    @PostMapping("/initiate")
    public TransactionResponse initiateTransaction(@Valid @RequestBody InitiateTransactionRequest request) {
        return transactionService.initiateTransaction(request);
    }

    @PostMapping("/authorize")
    public TransactionResponse authorizeTransaction(@Valid @RequestBody AuthorizeTransactionRequest request) {
        return transactionService.authorizeTransaction(request);
    }

    @PostMapping("/settle")
    public TransactionResponse settleTransaction(@Valid @RequestBody SettleTransactionRequest request) {
        return transactionService.settleTransaction(request);
    }

    @GetMapping("/{id}")
    public TransactionResponse getTransactionById(@PathVariable Long id) {
        return transactionService.getTransactionById(id);
    }
}