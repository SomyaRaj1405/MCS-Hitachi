package com.hitachi.mcs;

import com.hitachi.mcs.entity.Bill;
import com.hitachi.mcs.entity.Customer;
import com.hitachi.mcs.entity.Merchant;
import com.hitachi.mcs.kafka.TransactionEventProducer;
import com.hitachi.mcs.repository.BillRepository;
import com.hitachi.mcs.repository.CustomerRepository;
import com.hitachi.mcs.repository.MerchantRepository;
import com.hitachi.mcs.repository.SettlementRepository;
import com.hitachi.mcs.repository.TransactionRepository;
import com.hitachi.mcs.security.JwtUtil;
import com.hitachi.mcs.service.AuthorizationDecisionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SecurityControllerIntegrationTest {
    @Autowired private MockMvc mockMvc;
    @Autowired private JwtUtil jwtUtil;
    @Autowired private BillRepository billRepository;
    @Autowired private TransactionRepository transactionRepository;
    @Autowired private SettlementRepository settlementRepository;
    @Autowired private MerchantRepository merchantRepository;
    @Autowired private CustomerRepository customerRepository;

    @MockitoBean private TransactionEventProducer transactionEventProducer;
    @MockitoBean private AuthorizationDecisionService authorizationDecisionService;

    private Merchant merchant;
    private Customer customer;
    private Customer otherCustomer;

    @BeforeEach
    void setUp() {
        settlementRepository.deleteAll();
        transactionRepository.deleteAll();
        billRepository.deleteAll();
        merchantRepository.deleteAll();
        customerRepository.deleteAll();

        merchant = merchantRepository.save(merchant("merchant@security.test"));
        customer = customerRepository.save(customer("customer@security.test"));
        otherCustomer = customerRepository.save(customer("other@security.test"));

        Bill bill = new Bill();
        bill.setMerchant(merchant);
        bill.setCustomer(customer);
        bill.setAmount(new BigDecimal("500.00"));
        bill.setDescription("Security test bill");
        bill.setStatus("PENDING");
        billRepository.save(bill);
    }

    @Test
    void rejectsProtectedEndpointWithoutJwt() throws Exception {
        mockMvc.perform(get("/bills/customer/{id}", customer.getId()))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void customerCanReadOwnBillsThroughController() throws Exception {
        mockMvc.perform(get("/bills/customer/{id}", customer.getId())
                        .header("Authorization", bearer(customer.getEmail(), "CUSTOMER")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].customerId").value(customer.getId()));
    }

    @Test
    void customerCannotReadAnotherCustomersBills() throws Exception {
        mockMvc.perform(get("/bills/customer/{id}", otherCustomer.getId())
                        .header("Authorization", bearer(customer.getEmail(), "CUSTOMER")))
                .andExpect(status().isForbidden());
    }

    @Test
    void customerCannotUseMerchantBillEndpoint() throws Exception {
        mockMvc.perform(get("/bills/merchant/{id}", merchant.getId())
                        .header("Authorization", bearer(customer.getEmail(), "CUSTOMER")))
                .andExpect(status().isForbidden());
    }

    @Test
    void merchantCanReadOwnBills() throws Exception {
        mockMvc.perform(get("/bills/merchant/{id}", merchant.getId())
                        .header("Authorization", bearer(merchant.getEmail(), "MERCHANT")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].merchantId").value(merchant.getId()));
    }

    private String bearer(String email, String role) {
        return "Bearer " + jwtUtil.generateToken(email, role);
    }

    private Merchant merchant(String email) {
        Merchant value = new Merchant();
        value.setName("Security Merchant");
        value.setBusinessName("Security Store");
        value.setEmail(email);
        value.setPasswordHash("hash");
        return value;
    }

    private Customer customer(String email) {
        Customer value = new Customer();
        value.setName("Security Customer");
        value.setEmail(email);
        value.setPhone("9876543210");
        value.setPasswordHash("hash");
        return value;
    }
}
