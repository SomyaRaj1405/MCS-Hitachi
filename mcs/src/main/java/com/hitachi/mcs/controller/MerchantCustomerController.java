package com.hitachi.mcs.controller;

import com.hitachi.mcs.dto.MerchantCustomerPage;
import com.hitachi.mcs.dto.MerchantCustomerSummary;
import com.hitachi.mcs.service.MerchantCustomerService;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/customers/merchant")
public class MerchantCustomerController {
    private final MerchantCustomerService customerService;

    public MerchantCustomerController(MerchantCustomerService customerService) {
        this.customerService = customerService;
    }

    @GetMapping("/{merchantId}")
    @PreAuthorize("hasRole('MERCHANT') and @accessControlService.isMerchant(authentication, #merchantId)")
    public MerchantCustomerPage getCustomers(
            @PathVariable Long merchantId,
            @RequestParam(defaultValue = "") String search,
            @RequestParam(defaultValue = "ALL") String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return customerService.getCustomers(merchantId, search, status, page, size);
    }

    @GetMapping("/{merchantId}/{customerId}")
    @PreAuthorize("hasRole('MERCHANT') and @accessControlService.isMerchant(authentication, #merchantId)")
    public MerchantCustomerSummary getCustomer(
            @PathVariable Long merchantId,
            @PathVariable Long customerId) {
        return customerService.getCustomer(merchantId, customerId);
    }
}
