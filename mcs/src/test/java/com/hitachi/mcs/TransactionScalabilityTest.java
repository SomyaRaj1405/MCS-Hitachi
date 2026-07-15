package com.hitachi.mcs;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.hitachi.mcs.dto.BillRequest;
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
import com.hitachi.mcs.service.BillService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@EnabledIfSystemProperty(named = "mcs.performance.tests", matches = "true")
class TransactionScalabilityTest {
    private static final int TRANSACTION_COUNT = 1_000;
    private static final int MERCHANT_COUNT = 100;
    private static final double RESPONSE_TARGET_MS = 2_000.0;

    @Autowired private MockMvc mockMvc;
    @Autowired private ObjectMapper objectMapper;
    @Autowired private JwtUtil jwtUtil;
    @Autowired private BillService billService;
    @Autowired private BillRepository billRepository;
    @Autowired private TransactionRepository transactionRepository;
    @Autowired private SettlementRepository settlementRepository;
    @Autowired private MerchantRepository merchantRepository;
    @Autowired private CustomerRepository customerRepository;

    @MockitoBean private TransactionEventProducer transactionEventProducer;
    @MockitoBean private AuthorizationDecisionService authorizationDecisionService;

    private final List<Merchant> merchants = new ArrayList<>(MERCHANT_COUNT);
    private Customer customer;
    private String bearerToken;

    @BeforeEach
    void setUp() {
        settlementRepository.deleteAll();
        transactionRepository.deleteAll();
        billRepository.deleteAll();
        merchantRepository.deleteAll();
        customerRepository.deleteAll();

        merchants.clear();
        for (int index = 1; index <= MERCHANT_COUNT; index++) {
            Merchant merchant = new Merchant();
            merchant.setName("Scalability Merchant " + index);
            merchant.setBusinessName("MCS Load Store " + index);
            merchant.setEmail("merchant" + index + "@load.test");
            merchant.setPasswordHash("hash");
            merchants.add(merchantRepository.save(merchant));
        }

        customer = new Customer();
        customer.setName("Scalability Customer");
        customer.setEmail("customer@load.test");
        customer.setPhone("9876543210");
        customer.setPasswordHash("hash");
        customer = customerRepository.save(customer);

        bearerToken = "Bearer " + jwtUtil.generateToken(customer.getEmail(), "CUSTOMER");
        when(authorizationDecisionService.approve()).thenReturn(true);
    }

    @Test
    void completesOneThousandRestTransactionLifecyclesWithinResponseTarget() throws Exception {
        List<Double> responseTimesMs = new ArrayList<>(TRANSACTION_COUNT * 3);
        Instant startedAt = Instant.now();

        for (int index = 1; index <= TRANSACTION_COUNT; index++) {
            Long billId = createBill(index);
            JsonNode initiated = performTimedPost(
                    "/transactions/initiate",
                    "{\"billId\":" + billId + ",\"paymentMethod\":\"UPI\"}",
                    responseTimesMs);
            long transactionId = initiated.get("id").asLong();

            JsonNode authorized = performTimedPost(
                    "/transactions/authorize",
                    "{\"transactionId\":" + transactionId + "}",
                    responseTimesMs);
            assertThat(authorized.get("status").asText()).isEqualTo("AUTHORIZED");

            JsonNode settled = performTimedPost(
                    "/transactions/settle",
                    "{\"transactionId\":" + transactionId + "}",
                    responseTimesMs);
            assertThat(settled.get("status").asText()).isEqualTo("SETTLED");
        }

        Duration elapsed = Duration.between(startedAt, Instant.now());
        Collections.sort(responseTimesMs);
        double p95Ms = percentile(responseTimesMs, 0.95);
        double averageMs = responseTimesMs.stream().mapToDouble(Double::doubleValue).average().orElse(0);
        double maxMs = responseTimesMs.get(responseTimesMs.size() - 1);
        double throughput = TRANSACTION_COUNT / Math.max(elapsed.toMillis() / 1_000.0, 0.001);

        assertThat(transactionRepository.count()).isEqualTo(TRANSACTION_COUNT);
        assertThat(settlementRepository.count()).isEqualTo(TRANSACTION_COUNT);
        assertThat(merchantRepository.count()).isEqualTo(MERCHANT_COUNT);
        assertThat(p95Ms).isLessThan(RESPONSE_TARGET_MS);

        writeReport(elapsed, averageMs, p95Ms, maxMs, throughput);
        System.out.printf(Locale.ROOT,
                "MCS_PERFORMANCE merchants=%d transactions=%d requests=%d elapsedMs=%d throughputTxPerSec=%.2f averageMs=%.2f p95Ms=%.2f maxMs=%.2f failures=0%n",
                MERCHANT_COUNT, TRANSACTION_COUNT, responseTimesMs.size(), elapsed.toMillis(), throughput,
                averageMs, p95Ms, maxMs);
    }

    private JsonNode performTimedPost(String endpoint, String body, List<Double> timings) throws Exception {
        long started = System.nanoTime();
        MvcResult result = mockMvc.perform(post(endpoint)
                        .header("Authorization", bearerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andReturn();
        timings.add((System.nanoTime() - started) / 1_000_000.0);
        return objectMapper.readTree(result.getResponse().getContentAsString());
    }

    private Long createBill(int index) {
        BillRequest request = new BillRequest();
        Merchant merchant = merchants.get((index - 1) % MERCHANT_COUNT);
        request.setMerchantId(merchant.getId());
        request.setCustomerId(customer.getId());
        request.setAmount(new BigDecimal("10.00"));
        request.setDescription("Scalability transaction " + index);
        return billService.createBill(request).getId();
    }

    private double percentile(List<Double> values, double percentile) {
        int index = (int) Math.ceil(percentile * values.size()) - 1;
        return values.get(Math.max(0, Math.min(index, values.size() - 1)));
    }

    private void writeReport(Duration elapsed, double averageMs, double p95Ms,
                             double maxMs, double throughput) throws Exception {
        Path reportDirectory = Path.of("target", "performance-reports");
        Files.createDirectories(reportDirectory);
        String json = objectMapper.writerWithDefaultPrettyPrinter().writeValueAsString(objectMapper.createObjectNode()
                .put("transactions", TRANSACTION_COUNT)
                .put("merchants", MERCHANT_COUNT)
                .put("httpRequests", TRANSACTION_COUNT * 3)
                .put("failures", 0)
                .put("elapsedMilliseconds", elapsed.toMillis())
                .put("throughputTransactionsPerSecond", throughput)
                .put("averageResponseMilliseconds", averageMs)
                .put("p95ResponseMilliseconds", p95Ms)
                .put("maximumResponseMilliseconds", maxMs)
                .put("responseTargetMilliseconds", RESPONSE_TARGET_MS)
                .put("targetPassed", p95Ms < RESPONSE_TARGET_MS)
                .put("environment", "Spring Boot application context, MockMvc HTTP boundary, H2 PostgreSQL mode; 100 merchants with 10 transactions each"));
        Files.writeString(reportDirectory.resolve("1000-transactions.json"), json);
    }
}
