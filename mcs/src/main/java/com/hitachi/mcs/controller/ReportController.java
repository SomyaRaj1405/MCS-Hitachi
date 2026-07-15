package com.hitachi.mcs.controller;

import com.hitachi.mcs.dto.ReportResponse;
import com.hitachi.mcs.service.ReportService;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;

@RestController
@RequestMapping("/reports")
public class ReportController {

    private final ReportService reportService;

    public ReportController(ReportService reportService) {
        this.reportService = reportService;
    }

    @GetMapping("/daily")
    @PreAuthorize("hasRole('MERCHANT') and @accessControlService.isMerchant(authentication, #merchantId)")
    public ReportResponse getDailyReport(@RequestParam Long merchantId) {
        return reportService.getDailyReport(merchantId);
    }

    @GetMapping("/weekly")
    @PreAuthorize("hasRole('MERCHANT') and @accessControlService.isMerchant(authentication, #merchantId)")
    public ReportResponse getWeeklyReport(@RequestParam Long merchantId) {
        return reportService.getWeeklyReport(merchantId);
    }
}
