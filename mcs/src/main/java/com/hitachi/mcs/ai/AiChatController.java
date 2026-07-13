package com.hitachi.mcs.ai;

import com.hitachi.mcs.ai.IntentClassifierClient.ClassificationResult;
import com.hitachi.mcs.ai.IntentParserService.ChatIntent;
import com.hitachi.mcs.ai.IntentParserService.ParsedIntent;
import com.hitachi.mcs.entity.Bill;
import com.hitachi.mcs.entity.Customer;
import com.hitachi.mcs.entity.Merchant;
import com.hitachi.mcs.repository.BillRepository;
import com.hitachi.mcs.repository.CustomerRepository;
import com.hitachi.mcs.repository.MerchantRepository;
import com.hitachi.mcs.security.JwtUtil;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/ai")
public class AiChatController {

    @Autowired private IntentParserService intentParserService;
    @Autowired private BillRepository billRepository;
    @Autowired private MerchantRepository merchantRepository;
    @Autowired private CustomerRepository customerRepository;
    @Autowired private JwtUtil jwtUtil;

    // NEW - classifier + templated response upgrade
    @Autowired private IntentClassifierClient intentClassifierClient;
    @Autowired private TemplatedResponseService templatedResponseService;

    @PostMapping("/chat")
    public ChatResponse chat(@RequestHeader("Authorization") String authHeader,
                             @RequestBody ChatRequest request) {
        String token = authHeader.replace("Bearer ", "");
        String email = jwtUtil.extractEmail(token);
        String role = jwtUtil.extractRole(token); // "MERCHANT" or "CUSTOMER"

        Long userId = resolveUserId(email, role);

        ParsedIntent parsed = intentParserService.parse(request.getMessage(), role);

        // Existing rule-based path — completely unchanged. Fast, deterministic,
        // handles anything the parser recognizes.
        if (parsed.intent != ChatIntent.UNKNOWN) {
            String reply = handleIntent(parsed, role, userId);
            return new ChatResponse(reply, parsed.intent.name());
        }

        // NEW - LLM upgrade: rule-based parser had no match, so ask the
        // Python classifier for a second opinion before giving up.
        return handleWithClassifierAndLlm(request.getMessage(), role, userId);
    }

    // ---------- NEW: classifier + LLM fallback ----------

    private ChatResponse handleWithClassifierAndLlm(String message, String role, Long userId) {
        ClassificationResult classification = intentClassifierClient.classify(message);

        if (!classification.isReliable()) {
            // Neither the rules nor the classifier are confident — same
            // behavior as before this upgrade existed.
            return new ChatResponse(buildHelp(role), "UNKNOWN");
        }

        String intent = classification.getIntent();
        String dataContext = buildDataContext(intent, role, userId);
        String reply = templatedResponseService.generateReply(message, role, dataContext, intent);

        return new ChatResponse(reply, "AI_" + intent.toUpperCase());
    }

    /**
     * Pulls real data from Postgres for money-related intents so the LLM
     * phrases actual figures instead of guessing. Returns null for intents
     * that don't need grounding (general_faq, refund_help policy questions).
     */
    private String buildDataContext(String intent, String role, Long userId) {
        switch (intent) {
            case "transaction_query":
            case "report_request":
                return "MERCHANT".equalsIgnoreCase(role)
                        ? summarizeMerchantActivity(userId)
                        : summarizeCustomerActivity(userId);
            case "account_info":
                return "MERCHANT".equalsIgnoreCase(role)
                        ? summarizeMerchantAccount(userId)
                        : summarizeCustomerAccount(userId);
            default:
                // refund_help, general_faq, greeting — no data needed
                return null;
        }
    }

    private String summarizeMerchantActivity(Long merchantId) {
        List<Bill> pending = billRepository.findByMerchantIdAndStatus(merchantId, "PENDING");
        List<Bill> paid = billRepository.findByMerchantIdAndStatus(merchantId, "PAID");
        BigDecimal pendingTotal = pending.stream().map(Bill::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal paidTotal = paid.stream().map(Bill::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add);
        return "Pending bills: " + pending.size() + " totalling \u20B9" + pendingTotal + ". "
                + "Completed payments: " + paid.size() + " totalling \u20B9" + paidTotal + ".";
    }

    private String summarizeCustomerActivity(Long customerId) {
        List<Bill> pending = billRepository.findByCustomerIdAndStatus(customerId, "PENDING");
        List<Bill> paid = billRepository.findByCustomerIdAndStatus(customerId, "PAID");
        BigDecimal pendingTotal = pending.stream().map(Bill::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal paidTotal = paid.stream().map(Bill::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add);
        return "Pending payments: " + pending.size() + " totalling \u20B9" + pendingTotal + ". "
                + "Completed payments: " + paid.size() + " totalling \u20B9" + paidTotal + ".";
    }

    private String summarizeMerchantAccount(Long merchantId) {
        Merchant m = merchantRepository.findById(merchantId).orElse(null);
        if (m == null) return null;
        return "Merchant name: " + m.getName() + ", email: " + m.getEmail() + ".";
    }

    private String summarizeCustomerAccount(Long customerId) {
        Customer c = customerRepository.findById(customerId).orElse(null);
        if (c == null) return null;
        return "Customer name: " + c.getName() + ", email: " + c.getEmail() + ".";
    }

    // ---------- existing helpers below: unchanged ----------

    private Long resolveUserId(String email, String role) {
        if (role.equalsIgnoreCase("MERCHANT")) {
            Merchant merchant = merchantRepository.findByEmail(email)
                    .orElseThrow(() -> new RuntimeException("Merchant not found"));
            return merchant.getId();
        } else {
            Customer customer = customerRepository.findByEmail(email)
                    .orElseThrow(() -> new RuntimeException("Customer not found"));
            return customer.getId();
        }
    }

    private String handleIntent(ParsedIntent parsed, String role, Long userId) {
        switch (parsed.intent) {
            case GREETING:
                return buildGreeting(role);
            case HELP:
                return buildHelp(role);
            case MERCHANT_PENDING_CUSTOMERS:
                return buildMerchantPendingSummary(userId);
            case MERCHANT_CUSTOMER_AMOUNT:
                return buildMerchantCustomerAmount(userId, parsed.extractedName);
            case MERCHANT_TODAY_TRANSACTIONS:
                return buildMerchantTodayBills(userId);
            case MERCHANT_WEEK_TRANSACTIONS:
                return buildMerchantWeekBills(userId);
            case MERCHANT_TOTAL_RECEIVED:
                return buildMerchantTotalReceived(userId);
            case CUSTOMER_PENDING_MERCHANTS:
                return buildCustomerPendingSummary(userId);
            case CUSTOMER_MERCHANT_AMOUNT:
                return buildCustomerMerchantAmount(userId, parsed.extractedName);
            case CUSTOMER_LAST_PAYMENT:
                return buildCustomerLastPayment(userId);
            case CUSTOMER_TOTAL_PAID:
                return buildCustomerTotalPaid(userId);
            default:
                return buildHelp(role);
        }
    }

    // ---------- GENERAL ----------

    private String buildGreeting(String role) {
        return role.equalsIgnoreCase("MERCHANT")
                ? "Hi! I can tell you about pending payments, today's or this week's transactions, "
                + "or your total received. What would you like to know?"
                : "Hi! I can tell you what you owe, to whom, or your last payment. What would you like to know?";
    }

    private String buildHelp(String role) {
        return role.equalsIgnoreCase("MERCHANT")
                ? "I can help with things like:\n"
                + "- \"which customers are pending\"\n"
                + "- \"how much does <customer> owe\"\n"
                + "- \"today's transactions\" / \"this week's transactions\"\n"
                + "- \"how much have I received in total\""
                : "I can help with things like:\n"
                + "- \"which merchants do I owe\"\n"
                + "- \"how much do I owe <merchant>\"\n"
                + "- \"my last payment\"\n"
                + "- \"how much have I paid in total\"";
    }

    // ---------- MERCHANT ----------

    private String buildMerchantPendingSummary(Long merchantId) {
        List<Bill> pending = billRepository.findByMerchantIdAndStatus(merchantId, "PENDING");
        if (pending.isEmpty()) {
            return "No customers currently have pending payments.";
        }

        Map<String, BigDecimal> byCustomer = new LinkedHashMap<>();
        for (Bill bill : pending) {
            String name = bill.getCustomer().getName();
            byCustomer.merge(name, bill.getAmount(), BigDecimal::add);
        }

        BigDecimal total = byCustomer.values().stream().reduce(BigDecimal.ZERO, BigDecimal::add);
        StringBuilder sb = new StringBuilder("Pending payments:\n");
        byCustomer.forEach((name, amt) -> sb.append("- ").append(name).append(": \u20B9").append(amt).append("\n"));
        sb.append("Total pending: \u20B9").append(total);
        return sb.toString();
    }

    private String buildMerchantCustomerAmount(Long merchantId, String customerName) {
        if (customerName == null) {
            return "Which customer did you mean?";
        }
        List<Bill> pending = billRepository.findByMerchantIdAndStatus(merchantId, "PENDING");
        BigDecimal total = pending.stream()
                .filter(b -> b.getCustomer().getName().toLowerCase().contains(customerName.toLowerCase()))
                .map(Bill::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        if (total.compareTo(BigDecimal.ZERO) == 0) {
            return customerName + " has no pending payments.";
        }
        return customerName + " has a pending amount of \u20B9" + total + ".";
    }

    private String buildMerchantTodayBills(Long merchantId) {
        LocalDateTime start = LocalDate.now().atStartOfDay();
        LocalDateTime end = start.plusDays(1);
        List<Bill> today = billRepository.findByMerchantIdAndCreatedAtBetween(merchantId, start, end);

        if (today.isEmpty()) {
            return "No bills created today yet.";
        }
        BigDecimal total = today.stream().map(Bill::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add);
        return "Today: " + today.size() + " bill(s) created, totalling \u20B9" + total + ".";
    }

    private String buildMerchantWeekBills(Long merchantId) {
        LocalDateTime start = LocalDate.now().with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)).atStartOfDay();
        LocalDateTime end = LocalDateTime.now();
        List<Bill> thisWeek = billRepository.findByMerchantIdAndCreatedAtBetween(merchantId, start, end);

        if (thisWeek.isEmpty()) {
            return "No bills created this week yet.";
        }
        BigDecimal total = thisWeek.stream().map(Bill::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add);
        return "This week: " + thisWeek.size() + " bill(s) created, totalling \u20B9" + total + ".";
    }

    private String buildMerchantTotalReceived(Long merchantId) {
        List<Bill> paid = billRepository.findByMerchantIdAndStatus(merchantId, "PAID");
        if (paid.isEmpty()) {
            return "You haven't received any completed payments yet.";
        }
        BigDecimal total = paid.stream().map(Bill::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add);
        return "You've received \u20B9" + total + " in total across " + paid.size() + " payment(s).";
    }

    // ---------- CUSTOMER ----------

    private String buildCustomerPendingSummary(Long customerId) {
        List<Bill> pending = billRepository.findByCustomerIdAndStatus(customerId, "PENDING");
        if (pending.isEmpty()) {
            return "You have no pending payments right now.";
        }

        Map<String, BigDecimal> byMerchant = new LinkedHashMap<>();
        for (Bill bill : pending) {
            String name = bill.getMerchant().getName();
            byMerchant.merge(name, bill.getAmount(), BigDecimal::add);
        }

        BigDecimal total = byMerchant.values().stream().reduce(BigDecimal.ZERO, BigDecimal::add);
        StringBuilder sb = new StringBuilder("You owe:\n");
        byMerchant.forEach((name, amt) -> sb.append("- ").append(name).append(": \u20B9").append(amt).append("\n"));
        sb.append("Total owed: \u20B9").append(total);
        return sb.toString();
    }

    private String buildCustomerMerchantAmount(Long customerId, String merchantName) {
        if (merchantName == null) {
            return "Which merchant did you mean?";
        }
        List<Bill> pending = billRepository.findByCustomerIdAndStatus(customerId, "PENDING");
        BigDecimal total = pending.stream()
                .filter(b -> b.getMerchant().getName().toLowerCase().contains(merchantName.toLowerCase()))
                .map(Bill::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        if (total.compareTo(BigDecimal.ZERO) == 0) {
            return "You have no pending payments to " + merchantName + ".";
        }
        return "You owe " + merchantName + " \u20B9" + total + ".";
    }

    private String buildCustomerLastPayment(Long customerId) {
        Bill last = billRepository.findTopByCustomerIdAndStatusOrderByUpdatedAtDesc(customerId, "PAID");
        if (last == null) {
            return "No completed payments found yet.";
        }
        return "Your last payment was \u20B9" + last.getAmount() + " to " + last.getMerchant().getName() + ".";
    }

    private String buildCustomerTotalPaid(Long customerId) {
        List<Bill> paid = billRepository.findByCustomerIdAndStatus(customerId, "PAID");
        if (paid.isEmpty()) {
            return "You haven't completed any payments yet.";
        }
        BigDecimal total = paid.stream().map(Bill::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add);
        return "You've paid \u20B9" + total + " in total across " + paid.size() + " payment(s).";
    }

    // ---------- DTOs ----------

    public static class ChatRequest {
        private String message;
        public String getMessage() { return message; }
        public void setMessage(String message) { this.message = message; }
    }

    public static class ChatResponse {
        private String reply;
        private String intent;
        public ChatResponse(String reply, String intent) {
            this.reply = reply;
            this.intent = intent;
        }
        public String getReply() { return reply; }
        public String getIntent() { return intent; }
    }
}