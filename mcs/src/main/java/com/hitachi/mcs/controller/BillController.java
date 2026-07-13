package com.hitachi.mcs.controller;

import com.hitachi.mcs.dto.BillRequest;
import com.hitachi.mcs.dto.BillResponse;
import com.hitachi.mcs.dto.RefundRequest;
import com.hitachi.mcs.service.BillService;
import jakarta.validation.Valid;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/bills")
public class BillController {

    private final BillService billService;

    public BillController(BillService billService) {
        this.billService = billService;
    }

    @PostMapping
    public BillResponse createBill(@Valid @RequestBody BillRequest request) {
        return billService.createBill(request);
    }

    @GetMapping("/{id}")
    public BillResponse getBillById(@PathVariable Long id) {
        return billService.getBillById(id);
    }

    @GetMapping("/customer/{id}")
    public List<BillResponse> getBillsByCustomer(@PathVariable Long id) {
        return billService.getBillsByCustomer(id);
    }

    @GetMapping("/merchant/{id}")
    public List<BillResponse> getBillsByMerchant(@PathVariable Long id) {
        return billService.getBillsByMerchant(id);
    }

    @PostMapping("/{id}/refund")
    public BillResponse refundBill(@PathVariable Long id,
                                   @Valid @RequestBody(required = false) RefundRequest request) {
        return billService.refundBill(id, request);
    }

    @GetMapping(value = "/merchant/{id}/report.csv", produces = "text/csv")
    public ResponseEntity<byte[]> downloadMerchantReport(@PathVariable Long id) {
        byte[] report = billService.generateMerchantReportCsv(id);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("text/csv"))
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.attachment()
                        .filename("merchant-" + id + "-bills.csv").build().toString())
                .body(report);
    }
}