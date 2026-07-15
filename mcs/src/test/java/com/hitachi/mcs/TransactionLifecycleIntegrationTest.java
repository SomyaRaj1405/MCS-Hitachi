package com.hitachi.mcs;

import com.hitachi.mcs.dto.AuthorizeTransactionRequest;
import com.hitachi.mcs.dto.BillRequest;
import com.hitachi.mcs.dto.InitiateTransactionRequest;
import com.hitachi.mcs.dto.SettleTransactionRequest;
import com.hitachi.mcs.dto.TransactionResponse;
import com.hitachi.mcs.entity.Customer;
import com.hitachi.mcs.entity.Merchant;
import com.hitachi.mcs.kafka.TransactionEventProducer;
import com.hitachi.mcs.repository.BillRepository;
import com.hitachi.mcs.repository.CustomerRepository;
import com.hitachi.mcs.repository.MerchantRepository;
import com.hitachi.mcs.repository.SettlementRepository;
import com.hitachi.mcs.repository.TransactionRepository;
import com.hitachi.mcs.service.AuthorizationDecisionService;
import com.hitachi.mcs.service.BillService;
import com.hitachi.mcs.service.TransactionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@SpringBootTest
@ActiveProfiles("test")
class TransactionLifecycleIntegrationTest {

    @Autowired private BillService billService;
    @Autowired private TransactionService transactionService;
    @Autowired private BillRepository billRepository;
    @Autowired private TransactionRepository transactionRepository;
    @Autowired private SettlementRepository settlementRepository;
    @Autowired private MerchantRepository merchantRepository;
    @Autowired private CustomerRepository customerRepository;

    @MockitoBean private TransactionEventProducer transactionEventProducer;
    @MockitoBean private AuthorizationDecisionService authorizationDecisionService;

    private Merchant merchant;
    private Customer customer;

    @BeforeEach
    void setUp() {
        settlementRepository.deleteAll();
        transactionRepository.deleteAll();
        billRepository.deleteAll();
        merchantRepository.deleteAll();
        customerRepository.deleteAll();

        merchant = new Merchant();
        merchant.setName("Demo Owner");
        merchant.setBusinessName("Demo Store");
        merchant.setEmail("merchant@test.local");
        merchant.setPasswordHash("hash");
        merchant = merchantRepository.save(merchant);

        customer = new Customer();
        customer.setName("Demo Customer");
        customer.setEmail("customer@test.local");
        customer.setPhone("9876543210");
        customer.setPasswordHash("hash");
        customer = customerRepository.save(customer);
    }

    @Test
    void successfulPaymentRunsInitiationAuthorizationAndSettlement() {
        when(authorizationDecisionService.approve()).thenReturn(true);
        Long billId = createBill("Successful payment");

        TransactionResponse initiated = transactionService.initiateTransaction(initiate(billId));
        TransactionResponse authorized = transactionService.authorizeTransaction(authorize(initiated.getId()));
        TransactionResponse settled = transactionService.settleTransaction(settle(initiated.getId()));

        assertThat(initiated.getStatus()).isEqualTo("INITIATED");
        assertThat(initiated.getInitiatedAt()).isNotNull();
        assertThat(authorized.getStatus()).isEqualTo("AUTHORIZED");
        assertThat(authorized.getAuthorizedAt()).isNotNull();
        assertThat(settled.getStatus()).isEqualTo("SETTLED");
        assertThat(settled.getSettledAt()).isNotNull();
        assertThat(settled.getSettlementReference()).startsWith("SETTLE-");
        assertThat(billRepository.findById(billId).orElseThrow().getStatus()).isEqualTo("PAID");
        assertThat(settlementRepository.findByTransactionId(initiated.getId())).isPresent();
    }

    @Test
    void failedAuthorizationLeavesBillPendingForRetry() {
        when(authorizationDecisionService.approve()).thenReturn(false);
        Long billId = createBill("Retryable payment");

        TransactionResponse initiated = transactionService.initiateTransaction(initiate(billId));
        TransactionResponse failed = transactionService.authorizeTransaction(authorize(initiated.getId()));

        assertThat(failed.getStatus()).isEqualTo("FAILED");
        assertThat(failed.getAuthorizedAt()).isNotNull();
        assertThat(billRepository.findById(billId).orElseThrow().getStatus()).isEqualTo("PENDING");
        assertThat(settlementRepository.findByTransactionId(initiated.getId())).isEmpty();
    }

    private Long createBill(String description) {
        BillRequest request = new BillRequest();
        request.setMerchantId(merchant.getId());
        request.setCustomerId(customer.getId());
        request.setAmount(new BigDecimal("1250.00"));
        request.setDescription(description);
        return billService.createBill(request).getId();
    }

    private InitiateTransactionRequest initiate(Long billId) {
        InitiateTransactionRequest request = new InitiateTransactionRequest();
        request.setBillId(billId);
        request.setPaymentMethod("UPI");
        return request;
    }

    private AuthorizeTransactionRequest authorize(Long transactionId) {
        AuthorizeTransactionRequest request = new AuthorizeTransactionRequest();
        request.setTransactionId(transactionId);
        return request;
    }

    private SettleTransactionRequest settle(Long transactionId) {
        SettleTransactionRequest request = new SettleTransactionRequest();
        request.setTransactionId(transactionId);
        return request;
    }
}
