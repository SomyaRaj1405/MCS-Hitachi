package com.hitachi.mcs.service;

import com.hitachi.mcs.dto.AuthorizeTransactionRequest;
import com.hitachi.mcs.dto.InitiateTransactionRequest;
import com.hitachi.mcs.dto.SettleTransactionRequest;
import com.hitachi.mcs.dto.TransactionResponse;
import com.hitachi.mcs.entity.Bill;
import com.hitachi.mcs.entity.Settlement;
import com.hitachi.mcs.entity.Transaction;
import com.hitachi.mcs.kafka.TransactionEvent;
import com.hitachi.mcs.kafka.TransactionEventProducer;
import com.hitachi.mcs.repository.BillRepository;
import com.hitachi.mcs.repository.SettlementRepository;
import com.hitachi.mcs.repository.TransactionRepository;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
public class TransactionService {

    private final TransactionRepository transactionRepository;
    private final BillRepository billRepository;
    private final SettlementRepository settlementRepository;
    private final TransactionEventProducer transactionEventProducer;

    public TransactionService(TransactionRepository transactionRepository,
                              BillRepository billRepository,
                              SettlementRepository settlementRepository,
                              TransactionEventProducer transactionEventProducer) {
        this.transactionRepository = transactionRepository;
        this.billRepository = billRepository;
        this.settlementRepository = settlementRepository;
        this.transactionEventProducer = transactionEventProducer;
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
        bill.setPaymentMethod(transaction.getPaymentMethod());
        billRepository.save(bill);

        transaction.setStatus("SETTLED");
        Transaction savedTransaction = transactionRepository.save(transaction);

        // NEW — publish a "transaction completed" event to Kafka.
        // This is fire-and-forget: the response below still returns
        // immediately, while report updates, audit logging, and
        // fraud checks happen asynchronously via the consumers.
        transactionEventProducer.publishTransactionCompleted(new TransactionEvent(
                String.valueOf(savedTransaction.getId()),
                bill.getMerchant().getId(),
                bill.getCustomer().getId(),
                bill.getAmount(),
                savedTransaction.getStatus(),
                savedTransaction.getPaymentMethod(),
                Instant.now()
        ));

        return mapToResponse(savedTransaction);
    }

    public TransactionResponse getTransactionById(Long id) {
        Transaction transaction = transactionRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Transaction not found"));

        return mapToResponse(transaction);
    }

    public List<TransactionResponse> getTransactionsByBill(Long billId) {
        return transactionRepository.findByBillId(billId)
                .stream()
                .map(this::mapToResponse)
                .toList();
    }

    public List<TransactionResponse> getTransactionsByMerchant(Long merchantId) {
        return transactionRepository.findByBillMerchantId(merchantId)
                .stream()
                .map(this::mapToResponse)
                .toList();
    }

    public List<TransactionResponse> getTransactionsByCustomer(Long customerId) {
        return transactionRepository.findByBillCustomerId(customerId)
                .stream()
                .map(this::mapToResponse)
                .toList();
    }

    private TransactionResponse mapToResponse(Transaction transaction) {
        TransactionResponse response = new TransactionResponse();
        Bill bill = transaction.getBill();

        response.setId(transaction.getId());
        response.setBillId(bill.getId());
        response.setMerchantId(bill.getMerchant().getId());
        response.setMerchantName(bill.getMerchant().getName());
        response.setCustomerId(bill.getCustomer().getId());
        response.setCustomerName(bill.getCustomer().getName());
        response.setAmount(bill.getAmount());
        response.setDescription(bill.getDescription());
        response.setPaymentMethod(transaction.getPaymentMethod());
        response.setStatus(transaction.getStatus());
        response.setBillStatus(bill.getStatus());
        response.setCreatedAt(transaction.getCreatedAt());
        response.setUpdatedAt(transaction.getUpdatedAt());

        return response;
    }
}