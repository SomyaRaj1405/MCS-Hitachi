package com.hitachi.mcs.service;

import com.hitachi.mcs.dto.BillRequest;
import com.hitachi.mcs.dto.BillResponse;
import com.hitachi.mcs.dto.RefundRequest;
import com.hitachi.mcs.entity.Bill;
import com.hitachi.mcs.entity.Customer;
import com.hitachi.mcs.entity.Merchant;
import com.hitachi.mcs.repository.BillRepository;
import com.hitachi.mcs.repository.CustomerRepository;
import com.hitachi.mcs.repository.MerchantRepository;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

@Service
public class BillService {

    private final BillRepository billRepository;
    private final MerchantRepository merchantRepository;
    private final CustomerRepository customerRepository;

    private static final DateTimeFormatter CSV_DATE_FORMAT =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    public BillService(BillRepository billRepository,
                       MerchantRepository merchantRepository,
                       CustomerRepository customerRepository) {
        this.billRepository = billRepository;
        this.merchantRepository = merchantRepository;
        this.customerRepository = customerRepository;
    }

    public BillResponse createBill(BillRequest request) {
        Merchant merchant = merchantRepository.findById(request.getMerchantId())
                .orElseThrow(() -> new RuntimeException("Merchant not found"));

        Customer customer = customerRepository.findById(request.getCustomerId())
                .orElseThrow(() -> new RuntimeException("Customer not found"));

        Bill bill = new Bill();
        bill.setMerchant(merchant);
        bill.setCustomer(customer);
        bill.setAmount(request.getAmount());
        bill.setDescription(request.getDescription());
        bill.setStatus("PENDING");

        Bill savedBill = billRepository.save(bill);
        return mapToResponse(savedBill);
    }

    public BillResponse getBillById(Long id) {
        Bill bill = billRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Bill not found"));

        return mapToResponse(bill);
    }

    public List<BillResponse> getBillsByCustomer(Long customerId) {
        return billRepository.findByCustomerId(customerId)
                .stream()
                .map(this::mapToResponse)
                .toList();
    }

    public List<BillResponse> getBillsByMerchant(Long merchantId) {
        return billRepository.findByMerchantId(merchantId)
                .stream()
                .map(this::mapToResponse)
                .toList();
    }

    // ---------- NEW: refund ----------

    /**
     * Marks a bill as REFUNDED. Only bills currently in PAID status are
     * eligible — this prevents refunding a bill that's still pending
     * (nothing was collected yet) or one that's already been refunded.
     */
    public BillResponse refundBill(Long billId, RefundRequest request) {
        Bill bill = billRepository.findById(billId)
                .orElseThrow(() -> new RuntimeException("Bill not found"));

        if (!"PAID".equalsIgnoreCase(bill.getStatus())) {
            throw new IllegalStateException(
                    "Only paid bills can be refunded. Current status: " + bill.getStatus());
        }

        bill.setStatus("REFUNDED");
        bill.setRefundedAt(LocalDateTime.now());
        if (request != null && request.getReason() != null && !request.getReason().isBlank()) {
            bill.setRefundReason(request.getReason().trim());
        }

        Bill saved = billRepository.save(bill);
        return mapToResponse(saved);
    }

    // ---------- NEW: CSV report ----------

    /**
     * Builds a CSV of all bills for a merchant. Returned as raw bytes so
     * the controller can stream it back with a file download header.
     */
    public byte[] generateMerchantReportCsv(Long merchantId) {
        return generateReportCsv(billRepository.findByMerchantId(merchantId));
    }

    public byte[] generateMerchantRefundReportCsv(Long merchantId) {
        List<Bill> refunds = billRepository.findByMerchantId(merchantId).stream()
                .filter(bill -> "REFUNDED".equalsIgnoreCase(bill.getStatus()))
                .toList();
        return generateReportCsv(refunds);
    }

    private byte[] generateReportCsv(List<Bill> bills) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try (PrintWriter writer = new PrintWriter(out, true, StandardCharsets.UTF_8)) {
            writer.println("Bill ID,Customer,Amount,Status,Payment Method,Description,Created At,Refunded At,Refund Reason");

            for (Bill bill : bills) {
                writer.println(String.join(",",
                        String.valueOf(bill.getId()),
                        csvEscape(bill.getCustomer().getName()),
                        bill.getAmount().toPlainString(),
                        csvEscape(bill.getStatus()),
                        csvEscape(bill.getPaymentMethod() != null ? bill.getPaymentMethod() : "N/A"),
                        csvEscape(bill.getDescription() != null ? bill.getDescription() : ""),
                        bill.getCreatedAt() != null ? bill.getCreatedAt().format(CSV_DATE_FORMAT) : "",
                        bill.getRefundedAt() != null ? bill.getRefundedAt().format(CSV_DATE_FORMAT) : "",
                        csvEscape(bill.getRefundReason() != null ? bill.getRefundReason() : "")
                ));
            }
        }

        return out.toByteArray();
    }

    private String csvEscape(String value) {
        if (value == null) return "";
        if (value.contains(",") || value.contains("\"") || value.contains("\n")) {
            return "\"" + value.replace("\"", "\"\"") + "\"";
        }
        return value;
    }

    private BillResponse mapToResponse(Bill bill) {
        BillResponse response = new BillResponse();

        response.setId(bill.getId());
        response.setMerchantId(bill.getMerchant().getId());
        response.setMerchantName(bill.getMerchant().getName());
        response.setCustomerId(bill.getCustomer().getId());
        response.setCustomerName(bill.getCustomer().getName());
        response.setAmount(bill.getAmount());
        response.setDescription(bill.getDescription());
        response.setStatus(bill.getStatus());
        response.setPaymentMethod(bill.getPaymentMethod());
        response.setRefundReason(bill.getRefundReason());
        response.setRefundedAt(bill.getRefundedAt());
        response.setCreatedAt(bill.getCreatedAt());
        response.setUpdatedAt(bill.getUpdatedAt());

        return response;
    }
}
