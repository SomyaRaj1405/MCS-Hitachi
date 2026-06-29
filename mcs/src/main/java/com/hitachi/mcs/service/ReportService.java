package com.hitachi.mcs.service;

import com.hitachi.mcs.dto.ReportResponse;
import com.hitachi.mcs.entity.Settlement;
import com.hitachi.mcs.repository.SettlementRepository;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Service
public class ReportService {

    private final SettlementRepository settlementRepository;

    public ReportService(SettlementRepository settlementRepository) {
        this.settlementRepository = settlementRepository;
    }

    public ReportResponse getDailyReport(Long merchantId) {
        LocalDateTime start = LocalDateTime.now().toLocalDate().atStartOfDay();
        LocalDateTime end = start.plusDays(1);
        return generateReport(merchantId, start, end, "DAILY");
    }

    public ReportResponse getWeeklyReport(Long merchantId) {
        LocalDateTime end = LocalDateTime.now();
        LocalDateTime start = end.minusDays(7);
        return generateReport(merchantId, start, end, "WEEKLY");
    }

    private ReportResponse generateReport(Long merchantId, LocalDateTime start, LocalDateTime end, String period) {
        List<Settlement> settlements = settlementRepository.findAll();

        List<Settlement> filtered = settlements.stream()
                .filter(s -> s.getSettledAt() != null)
                .filter(s -> !s.getSettledAt().isBefore(start) && s.getSettledAt().isBefore(end))
                .filter(s -> s.getTransaction().getBill().getMerchant().getId().equals(merchantId))
                .toList();

        BigDecimal totalRevenue = filtered.stream()
                .map(Settlement::getSettledAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        ReportResponse response = new ReportResponse();
        response.setMerchantId(merchantId);
        response.setPeriod(period);
        response.setTotalSettledTransactions((long) filtered.size());
        response.setTotalRevenue(totalRevenue);

        if (!filtered.isEmpty()) {
            response.setMerchantName(filtered.get(0).getTransaction().getBill().getMerchant().getName());
        } else {
            response.setMerchantName("No settled transactions found");
        }

        return response;
    }
}