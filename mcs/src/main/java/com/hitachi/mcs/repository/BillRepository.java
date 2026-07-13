package com.hitachi.mcs.repository;

import com.hitachi.mcs.entity.Bill;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface BillRepository extends JpaRepository<Bill, Long> {
    List<Bill> findByCustomerId(Long customerId);
    List<Bill> findByMerchantId(Long merchantId);

    // Added for the AI assistant
    List<Bill> findByMerchantIdAndStatus(Long merchantId, String status);
    List<Bill> findByCustomerIdAndStatus(Long customerId, String status);
    List<Bill> findByMerchantIdAndCreatedAtBetween(Long merchantId, LocalDateTime start, LocalDateTime end);
    Bill findTopByCustomerIdAndStatusOrderByUpdatedAtDesc(Long customerId, String status);
}