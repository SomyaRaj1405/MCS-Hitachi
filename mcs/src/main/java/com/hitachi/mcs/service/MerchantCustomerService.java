package com.hitachi.mcs.service;

import com.hitachi.mcs.dto.MerchantCustomerPage;
import com.hitachi.mcs.dto.MerchantCustomerSummary;
import com.hitachi.mcs.entity.Bill;
import com.hitachi.mcs.entity.Customer;
import com.hitachi.mcs.repository.BillRepository;
import com.hitachi.mcs.repository.MerchantRepository;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

@Service
public class MerchantCustomerService {
    private final BillRepository billRepository;
    private final MerchantRepository merchantRepository;

    public MerchantCustomerService(BillRepository billRepository,
                                   MerchantRepository merchantRepository) {
        this.billRepository = billRepository;
        this.merchantRepository = merchantRepository;
    }

    public MerchantCustomerPage getCustomers(Long merchantId, String search,
                                             String status, int page, int size) {
        requireMerchant(merchantId);
        List<MerchantCustomerSummary> summaries = aggregate(merchantId);
        String normalizedSearch = search == null ? "" : search.trim().toLowerCase(Locale.ROOT);
        String normalizedStatus = status == null ? "ALL" : status.trim().toUpperCase(Locale.ROOT);

        List<MerchantCustomerSummary> filtered = summaries.stream()
                .filter(item -> normalizedSearch.isEmpty()
                        || item.getName().toLowerCase(Locale.ROOT).contains(normalizedSearch)
                        || item.getEmail().toLowerCase(Locale.ROOT).contains(normalizedSearch)
                        || item.getCustomerId().toString().contains(normalizedSearch))
                .filter(item -> switch (normalizedStatus) {
                    case "OUTSTANDING" -> item.getOutstandingAmount().compareTo(BigDecimal.ZERO) > 0;
                    case "ACTIVE" -> Boolean.TRUE.equals(item.getActive());
                    default -> true;
                })
                .sorted(Comparator.comparing(
                        MerchantCustomerSummary::getLastPaymentAt,
                        Comparator.nullsLast(Comparator.reverseOrder())))
                .toList();

        int safeSize = Math.max(1, Math.min(size, 100));
        int totalPages = Math.max(1, (int) Math.ceil((double) filtered.size() / safeSize));
        int safePage = Math.max(0, Math.min(page, totalPages - 1));
        int from = Math.min(safePage * safeSize, filtered.size());
        int to = Math.min(from + safeSize, filtered.size());
        return new MerchantCustomerPage(
                filtered.subList(from, to), filtered.size(), totalPages, safePage, safeSize);
    }

    public MerchantCustomerSummary getCustomer(Long merchantId, Long customerId) {
        requireMerchant(merchantId);
        return aggregate(merchantId).stream()
                .filter(item -> item.getCustomerId().equals(customerId))
                .findFirst()
                .orElseThrow(() -> new RuntimeException("Customer is not connected to this merchant"));
    }

    private List<MerchantCustomerSummary> aggregate(Long merchantId) {
        Map<Long, List<Bill>> byCustomer = new LinkedHashMap<>();
        for (Bill bill : billRepository.findByMerchantId(merchantId)) {
            byCustomer.computeIfAbsent(bill.getCustomer().getId(), key -> new ArrayList<>()).add(bill);
        }

        return byCustomer.values().stream().map(bills -> {
            Customer customer = bills.get(0).getCustomer();
            long paid = count(bills, "PAID");
            long pending = count(bills, "PENDING");
            long failed = count(bills, "FAILED");
            long refunded = count(bills, "REFUNDED");
            BigDecimal totalPaid = sum(bills, "PAID");
            BigDecimal outstanding = sum(bills, "PENDING");
            BigDecimal refundedAmount = sum(bills, "REFUNDED");
            LocalDateTime lastPaymentAt = bills.stream()
                    .filter(bill -> "PAID".equalsIgnoreCase(bill.getStatus())
                            || "REFUNDED".equalsIgnoreCase(bill.getStatus()))
                    .map(Bill::getUpdatedAt)
                    .filter(value -> value != null)
                    .max(LocalDateTime::compareTo)
                    .orElse(null);
            return new MerchantCustomerSummary(
                    customer.getId(), customer.getName(), customer.getEmail(), customer.getPhone(),
                    customer.getIsActive(), bills.size(), paid, pending, failed, refunded,
                    totalPaid, outstanding, refundedAmount, lastPaymentAt);
        }).toList();
    }

    private long count(List<Bill> bills, String status) {
        return bills.stream().filter(bill -> status.equalsIgnoreCase(bill.getStatus())).count();
    }

    private BigDecimal sum(List<Bill> bills, String status) {
        return bills.stream()
                .filter(bill -> status.equalsIgnoreCase(bill.getStatus()))
                .map(Bill::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private void requireMerchant(Long merchantId) {
        if (!merchantRepository.existsById(merchantId)) {
            throw new RuntimeException("Merchant not found");
        }
    }
}
