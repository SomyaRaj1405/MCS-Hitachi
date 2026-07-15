package com.hitachi.mcs.controller;

import com.hitachi.mcs.dto.AuthorizeTransactionRequest;
import com.hitachi.mcs.dto.InitiateTransactionRequest;
import com.hitachi.mcs.dto.SettleTransactionRequest;
import com.hitachi.mcs.dto.TransactionResponse;
import com.hitachi.mcs.service.TransactionService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;

import java.util.List;

@RestController
@RequestMapping("/transactions")
public class TransactionController {

    private final TransactionService transactionService;

    public TransactionController(TransactionService transactionService) {
        this.transactionService = transactionService;
    }

    @PostMapping("/initiate")
    @PreAuthorize("hasRole('CUSTOMER') and @accessControlService.ownsBill(authentication, #request.billId)")
    public TransactionResponse initiateTransaction(@Valid @RequestBody InitiateTransactionRequest request) {
        return transactionService.initiateTransaction(request);
    }

    @PostMapping("/authorize")
    @PreAuthorize("hasRole('CUSTOMER') and @accessControlService.ownsTransaction(authentication, #request.transactionId)")
    public TransactionResponse authorizeTransaction(@Valid @RequestBody AuthorizeTransactionRequest request) {
        return transactionService.authorizeTransaction(request);
    }

    @PostMapping("/settle")
    @PreAuthorize("hasRole('CUSTOMER') and @accessControlService.ownsTransaction(authentication, #request.transactionId)")
    public TransactionResponse settleTransaction(@Valid @RequestBody SettleTransactionRequest request) {
        return transactionService.settleTransaction(request);
    }

    @GetMapping("/bill/{billId}")
    @PreAuthorize("@accessControlService.ownsBill(authentication, #billId)")
    public List<TransactionResponse> getTransactionsByBill(@PathVariable Long billId) {
        return transactionService.getTransactionsByBill(billId);
    }

    @GetMapping("/merchant/{merchantId}")
    @PreAuthorize("hasRole('MERCHANT') and @accessControlService.isMerchant(authentication, #merchantId)")
    public List<TransactionResponse> getTransactionsByMerchant(@PathVariable Long merchantId) {
        return transactionService.getTransactionsByMerchant(merchantId);
    }

    @GetMapping("/customer/{customerId}")
    @PreAuthorize("hasRole('CUSTOMER') and @accessControlService.isCustomer(authentication, #customerId)")
    public List<TransactionResponse> getTransactionsByCustomer(@PathVariable Long customerId) {
        return transactionService.getTransactionsByCustomer(customerId);
    }

    @GetMapping("/{id}")
    @PreAuthorize("@accessControlService.ownsTransaction(authentication, #id)")
    public TransactionResponse getTransactionById(@PathVariable Long id) {
        return transactionService.getTransactionById(id);
    }
}
