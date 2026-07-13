package com.hitachi.mcs.ai;

import org.springframework.stereotype.Service;

/**
 * Generates chatbot replies for intents the rule-based IntentParserService
 * doesn't recognize, but the Python classifier (IntentClassifierClient)
 * identified with confidence.
 *
 * This replaces a paid LLM API call with templated responses composed in
 * Java. Money-related answers (transaction_query, report_request,
 * account_info) are built directly from real data pulled from Postgres
 * (passed in as dataContext by the controller) — never invented.
 * General/policy questions (refund_help, general_faq) use static,
 * well-written answers, with light keyword sub-routing for general_faq
 * so common questions get a specific answer rather than one generic blob.
 *
 * Swappable later: if you ever want real LLM-generated answers, this
 * class can be replaced with one that calls an API, as long as it keeps
 * the same generateReply(...) signature the controller calls.
 */
@Service
public class TemplatedResponseService {

    public String generateReply(String userMessage, String role, String dataContext, String intent) {
        switch (intent) {
            case "transaction_query":
                return buildTransactionReply(role, dataContext);
            case "report_request":
                return buildReportReply(role, dataContext);
            case "account_info":
                return buildAccountInfoReply(role, dataContext);
            case "refund_help":
                return buildRefundHelpReply();
            case "general_faq":
                return buildGeneralFaqReply(userMessage);
            case "greeting":
                return buildGreetingReply(role);
            default:
                return "I'm not sure how to help with that yet. Type \"help\" to see what I can answer.";
        }
    }

    // ---------- transaction_query / report_request: real data, phrased ----------

    private String buildTransactionReply(String role, String dataContext) {
        if (dataContext == null || dataContext.isBlank()) {
            return "I couldn't find any transaction data for your account right now.";
        }
        String who = "MERCHANT".equalsIgnoreCase(role) ? "your account" : "your payments";
        return "Here's a summary of " + who + ": " + dataContext;
    }

    private String buildReportReply(String role, String dataContext) {
        if (dataContext == null || dataContext.isBlank()) {
            return "I couldn't find any data to summarize for a report right now.";
        }
        return "I don't have a downloadable report export yet, but here's the current summary: "
                + dataContext
                + " For a full report, please check the Reports section of your dashboard.";
    }

    // ---------- account_info: real data, phrased ----------

    private String buildAccountInfoReply(String role, String dataContext) {
        if (dataContext == null || dataContext.isBlank()) {
            return "I couldn't retrieve your account details right now. Please check the Account section of your dashboard.";
        }
        return "Here's what's on file for your account: " + dataContext;
    }

    // ---------- refund_help: static policy answer ----------

    private String buildRefundHelpReply() {
        return "Refunds are typically processed back to the original payment method within 5-7 "
                + "business days once approved. To request one, go to the transaction in question "
                + "and select \"Request Refund.\" Partial refunds are supported. If a refund shows "
                + "as pending for longer than expected, please contact support with the transaction ID.";
    }

    // ---------- general_faq: keyword-routed static answers ----------

    private String buildGeneralFaqReply(String message) {
        String msg = message == null ? "" : message.toLowerCase();

        if (containsAny(msg, "fee", "fees", "charge", "cost", "pricing")) {
            return "Transaction fees depend on the payment method and merchant plan. You can see "
                    + "the exact breakdown for your account in the Billing section of your dashboard.";
        }
        if (containsAny(msg, "secure", "security", "safe", "pci", "compliant", "compliance")) {
            return "The platform follows PCI DSS security standards, uses tokenization so card "
                    + "details are never stored directly, and supports 3D Secure authentication "
                    + "on card payments.";
        }
        if (containsAny(msg, "international", "currency", "currencies", "abroad", "foreign")) {
            return "International payments and multiple currencies are supported, though "
                    + "availability can depend on your merchant plan. Check the Settings section "
                    + "for the currencies enabled on your account.";
        }
        if (containsAny(msg, "settlement", "when do i get paid", "payout")) {
            return "Settlement timing depends on your merchant tier, but standard settlement "
                    + "cycles run T+1 to T+3 business days after a successful payment.";
        }
        if (containsAny(msg, "api", "integrate", "integration", "webhook")) {
            return "API integration docs and webhook setup guides are available in the Developer "
                    + "section of your dashboard. If you're stuck on a specific step, let me know "
                    + "what you're trying to do.";
        }
        if (containsAny(msg, "support", "contact", "help desk", "human")) {
            return "You can reach support through the Help section of your dashboard, or email "
                    + "the support address listed there for account-specific issues.";
        }

        return "That's a general platform question I don't have a specific answer template for yet. "
                + "Try checking the Help section of your dashboard, or contact support for details.";
    }

    // ---------- greeting fallback (rarely reached, rule-based usually catches this) ----------

    private String buildGreetingReply(String role) {
        return "MERCHANT".equalsIgnoreCase(role)
                ? "Hi! Ask me about your pending payments, transactions, or account details."
                : "Hi! Ask me about what you owe, your payment history, or your account details.";
    }

    private boolean containsAny(String msg, String... keywords) {
        for (String k : keywords) {
            if (msg.contains(k)) return true;
        }
        return false;
    }
}