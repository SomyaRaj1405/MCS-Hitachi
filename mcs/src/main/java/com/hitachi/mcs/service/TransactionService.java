package com.hitachi.mcs.service;

import com.hitachi.mcs.dto.AuthorizeTransactionRequest;
import com.hitachi.mcs.dto.InitiateTransactionRequest;
import com.hitachi.mcs.dto.SettleTransactionRequest;
import com.hitachi.mcs.dto.TransactionResponse;
import com.hitachi.mcs.entity.Bill;
import com.hitachi.mcs.entity.Settlement;
import com.hitachi.mcs.entity.Transaction;
import com.hitachi.mcs.repository.BillRepository;
import com.hitachi.mcs.repository.SettlementRepository;
import com.hitachi.mcs.repository.TransactionRepository;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
public class TransactionService {

    private final TransactionRepository transactionRepository;
    private final BillRepository billRepository;
    private final SettlementRepository settlementRepository;

    public TransactionService(TransactionRepository transactionRepository,
                              BillRepository billRepository,
                              SettlementRepository settlementRepository) {
        this.transactionRepository = transactionRepository;
        this.billRepository = billRepository;
        this.settlementRepository = settlementRepository;
    }

    public TransactionResponse initiateTransaction(InitiateTransactionRequest request) {
        Bill bill = billRepository.findById(request.getBillId())
                .orElseThrow(() -> new RuntimeException("Bill not found"));

        if (!"PENDING".equalsIgnoreCase(bill.getStatus())) {
            throw new RuntimeException("Only PENDING bills can be paid");
        }

        Transaction transaction = new Transaction();
        transaction.setBill(bill);
        transaction.setPaymentMethod(request.getPaymentMethod());
        transaction.setStatus("INITIATED");

        Transaction savedTransaction = transactionRepository.save(transaction);
        return mapToResponse(savedTransaction);
    }

    public TransactionResponse authorizeTransaction(AuthorizeTransactionRequest request) {
        Transaction transaction = transactionRepository.findById(request.getTransactionId())
                .orElseThrow(() -> new RuntimeException("Transaction not found"));

        if (!"INITIATED".equalsIgnoreCase(transaction.getStatus())) {
            throw new RuntimeException("Only INITIATED transactions can be authorized");
        }

        boolean success = Math.random() < 0.9;

        if (success) {
            transaction.setStatus("AUTHORIZED");
        } else {
            transaction.setStatus("FAILED");
        }

        Transaction savedTransaction = transactionRepository.save(transaction);
        return mapToResponse(savedTransaction);
    }

    public TransactionResponse settleTransaction(SettleTransactionRequest request) {
        Transaction transaction = transactionRepository.findById(request.getTransactionId())
                .orElseThrow(() -> new RuntimeException("Transaction not found"));

        if (!"AUTHORIZED".equalsIgnoreCase(transaction.getStatus())) {
            throw new RuntimeException("Only AUTHORIZED transactions can be settled");
        }

        Bill bill = transaction.getBill();

        Settlement settlement = new Settlement();
        settlement.setTransaction(transaction);
        settlement.setSettledAmount(bill.getAmount());
        settlement.setReferenceNumber("SETTLE-" + UUID.randomUUID());

        settlementRepository.save(settlement);

        bill.setStatus("PAID");
        billRepository.save(bill);

        transaction.setStatus("SETTLED");
        Transaction savedTransaction = transactionRepository.save(transaction);

        return mapToResponse(savedTransaction);
    }

    public TransactionResponse getTransactionById(Long id) {
        Transaction transaction = transactionRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Transaction not found"));

        return mapToResponse(transaction);
    }

    private TransactionResponse mapToResponse(Transaction transaction) {
        TransactionResponse response = new TransactionResponse();

        response.setId(transaction.getId());
        response.setBillId(transaction.getBill().getId());
        response.setAmount(transaction.getBill().getAmount());
        response.setPaymentMethod(transaction.getPaymentMethod());
        response.setStatus(transaction.getStatus());
        response.setBillStatus(transaction.getBill().getStatus());
        response.setCreatedAt(transaction.getCreatedAt());
        response.setUpdatedAt(transaction.getUpdatedAt());

        return response;
    }
}