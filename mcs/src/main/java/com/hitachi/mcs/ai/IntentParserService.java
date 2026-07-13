package com.hitachi.mcs.ai;

import org.springframework.stereotype.Service;

import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Parses a free-text chat message into one of a fixed set of intents.
 * No LLM involved — this is keyword/regex matching against a small,
 * known vocabulary, with a typo-correction pass applied first so
 * common misspellings ("pendign", "todya") still match correctly.
 *
 * Add new intents here as you add new capabilities. Everything else
 * (controller, response building) stays unchanged.
 */
@Service
public class IntentParserService {

    public enum ChatIntent {
        MERCHANT_PENDING_CUSTOMERS,      // "who owes me", "which customers are pending"
        MERCHANT_CUSTOMER_AMOUNT,        // "how much does <name> owe" / "is <name> pending"
        MERCHANT_TODAY_TRANSACTIONS,     // "today's transactions", "what came in today"
        MERCHANT_WEEK_TRANSACTIONS,      // "this week's transactions", "transactions this week"
        MERCHANT_TOTAL_RECEIVED,         // "how much have I received", "total revenue"
        CUSTOMER_PENDING_MERCHANTS,      // "which merchants do I owe", "what do I owe"
        CUSTOMER_MERCHANT_AMOUNT,        // "how much do I owe <merchant>"
        CUSTOMER_LAST_PAYMENT,           // "my last payment", "last transaction"
        CUSTOMER_TOTAL_PAID,             // "how much have I paid", "total spent"
        GREETING,                        // "hi", "hello", "hey"
        HELP,                            // "help", "what can you do"
        UNKNOWN
    }

    public static class ParsedIntent {
        public final ChatIntent intent;
        public final String extractedName; // merchant or customer name, if present

        public ParsedIntent(ChatIntent intent, String extractedName) {
            this.intent = intent;
            this.extractedName = extractedName;
        }
    }

    // Captures a name after phrases like "does X owe", "is X pending", "owe X"
    private static final Pattern NAME_PATTERN = Pattern.compile(
            "(?:does|is|for|to)\\s+([a-zA-Z][a-zA-Z\\s]{1,40}?)\\s+(?:owe|pending|paid)",
            Pattern.CASE_INSENSITIVE
    );

    // Fallback: "how much do I owe <name>" / "how much is <name> pending"
    private static final Pattern TRAILING_NAME_PATTERN = Pattern.compile(
            "(?:owe|pending)\\s+([a-zA-Z][a-zA-Z\\s]{1,40}?)\\??$",
            Pattern.CASE_INSENSITIVE
    );

    // Known vocabulary used for typo correction — every word here is one
    // that keyword matching below actually looks for. Extend this list
    // whenever you add a new keyword to containsAny(...) calls.
    private static final Set<String> VOCABULARY = Set.of(
            "pending", "owe", "owes", "today", "week", "transactions",
            "last", "payment", "recent", "merchant", "merchants",
            "customer", "customers", "who", "which", "total", "paid",
            "received", "revenue", "help", "hello", "hi", "hey",
            "commands", "spent", "do"
    );

    public ParsedIntent parse(String rawMessage, String role) {
        String msg = rawMessage == null ? "" : rawMessage.trim().toLowerCase();
        String normalized = correctTypos(msg);

        if (containsAny(normalized, "hello", "hi", "hey")) {
            return new ParsedIntent(ChatIntent.GREETING, null);
        }
        if (containsAny(normalized, "help", "what can you do", "commands")) {
            return new ParsedIntent(ChatIntent.HELP, null);
        }

        if ("MERCHANT".equalsIgnoreCase(role)) {
            if (containsAny(normalized, "this week", "week's transactions", "transactions this week")) {
                return new ParsedIntent(ChatIntent.MERCHANT_WEEK_TRANSACTIONS, null);
            }
            if (containsAny(normalized, "today", "today's transactions", "transactions today")) {
                return new ParsedIntent(ChatIntent.MERCHANT_TODAY_TRANSACTIONS, null);
            }
            if (containsAny(normalized, "total received", "how much have i received", "total revenue")) {
                return new ParsedIntent(ChatIntent.MERCHANT_TOTAL_RECEIVED, null);
            }
            String name = extractName(rawMessage);
            if (name != null) {
                return new ParsedIntent(ChatIntent.MERCHANT_CUSTOMER_AMOUNT, name);
            }
            if (containsAny(normalized, "pending", "owe me", "who owes", "which customers")) {
                return new ParsedIntent(ChatIntent.MERCHANT_PENDING_CUSTOMERS, null);
            }
        }

        if ("CUSTOMER".equalsIgnoreCase(role)) {
            if (containsAny(normalized, "last payment", "last transaction", "recent payment")) {
                return new ParsedIntent(ChatIntent.CUSTOMER_LAST_PAYMENT, null);
            }
            if (containsAny(normalized, "total paid", "how much have i paid", "total spent")) {
                return new ParsedIntent(ChatIntent.CUSTOMER_TOTAL_PAID, null);
            }
            String name = extractName(rawMessage);
            if (name != null) {
                return new ParsedIntent(ChatIntent.CUSTOMER_MERCHANT_AMOUNT, name);
            }
            if (containsAny(normalized, "do i owe", "which merchants", "what do i owe", "pending")) {
                return new ParsedIntent(ChatIntent.CUSTOMER_PENDING_MERCHANTS, null);
            }
        }

        return new ParsedIntent(ChatIntent.UNKNOWN, null);
    }

    private String extractName(String rawMessage) {
        Matcher m1 = NAME_PATTERN.matcher(rawMessage);
        if (m1.find()) {
            return clean(m1.group(1));
        }
        Matcher m2 = TRAILING_NAME_PATTERN.matcher(rawMessage.trim());
        if (m2.find()) {
            return clean(m2.group(1));
        }
        return null;
    }

    private String clean(String s) {
        return s.trim().replaceAll("\\s+", " ");
    }

    private boolean containsAny(String msg, String... keywords) {
        for (String k : keywords) {
            if (msg.contains(k)) return true;
        }
        return false;
    }

    /**
     * Corrects likely typos word-by-word against the known VOCABULARY,
     * using Levenshtein distance. A word is replaced only if it's close
     * enough to a single vocabulary word to be a confident correction —
     * this deliberately leaves names, amounts, and unrelated words
     * untouched, so it only smooths over misspellings of the keywords
     * the parser actually looks for.
     */
    private String correctTypos(String msg) {
        String[] words = msg.split("\\s+");
        StringBuilder corrected = new StringBuilder();

        for (String word : words) {
            String cleanWord = word.replaceAll("[^a-z]", "");
            if (cleanWord.isEmpty()) {
                corrected.append(word).append(" ");
                continue;
            }
            if (VOCABULARY.contains(cleanWord)) {
                corrected.append(word).append(" ");
                continue;
            }

            String closest = closestVocabWord(cleanWord);
            corrected.append(closest != null ? closest : word).append(" ");
        }

        return corrected.toString().trim();
    }

    private String closestVocabWord(String word) {
        // Skip very short words — too easy to false-positive-match
        // (e.g. "hi" vs "do", "to" vs "do").
        if (word.length() < 3) {
            return null;
        }

        String best = null;
        int bestDistance = Integer.MAX_VALUE;

        for (String vocabWord : VOCABULARY) {
            int distance = levenshtein(word, vocabWord);
            if (distance < bestDistance) {
                bestDistance = distance;
                best = vocabWord;
            }
        }

        // Allow more edit distance for longer words, since a couple of
        // typo'd characters in a long word is still an obvious match,
        // but the same distance on a short word is likely a different
        // word entirely.
        int threshold = word.length() <= 4 ? 1 : (word.length() <= 7 ? 2 : 3);

        return (bestDistance <= threshold) ? best : null;
    }

    private int levenshtein(String a, String b) {
        int[][] dp = new int[a.length() + 1][b.length() + 1];

        for (int i = 0; i <= a.length(); i++) dp[i][0] = i;
        for (int j = 0; j <= b.length(); j++) dp[0][j] = j;

        for (int i = 1; i <= a.length(); i++) {
            for (int j = 1; j <= b.length(); j++) {
                int cost = (a.charAt(i - 1) == b.charAt(j - 1)) ? 0 : 1;
                dp[i][j] = Math.min(
                        Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1),
                        dp[i - 1][j - 1] + cost
                );
            }
        }

        return dp[a.length()][b.length()];
    }
}