package com.hitachi.mcs.controller;

import com.hitachi.mcs.dto.BillRequest;
import com.hitachi.mcs.dto.BillResponse;
import com.hitachi.mcs.service.BillService;
import jakarta.validation.Valid;
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
}