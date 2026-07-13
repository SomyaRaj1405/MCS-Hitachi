package com.hitachi.mcs.repository;

import com.hitachi.mcs.entity.Transaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface TransactionRepository extends JpaRepository<Transaction, Long> {
    List<Transaction> findByBillId(Long billId);
    List<Transaction> findByBillMerchantId(Long merchantId);
    List<Transaction> findByBillCustomerId(Long customerId);

    // NEW — used by FraudCheckConsumer as a velocity signal: how many
    // transactions has this customer made in the last 24 hours.
    long countByBillCustomerIdAndCreatedAtAfter(Long customerId, LocalDateTime since);

    // NEW — used by FraudCheckConsumer to compute how far a transaction's
    // amount deviates from this merchant's historical average.
    @Query("SELECT AVG(t.bill.amount) FROM Transaction t WHERE t.bill.merchant.id = :merchantId")
    Double findAverageAmountByMerchantId(@Param("merchantId") Long merchantId);

    // NEW — used by AnalyticsController for the revenue forecast chart.
    // Returns [date, totalRevenue] pairs for settled transactions since a given time.
    @Query("SELECT FUNCTION('DATE', t.createdAt) as day, SUM(t.bill.amount) as total " +
           "FROM Transaction t WHERE t.status = 'SETTLED' AND t.createdAt >= :since " +
           "GROUP BY FUNCTION('DATE', t.createdAt) ORDER BY day")
    List<Object[]> findDailyRevenueSince(@Param("since") LocalDateTime since);
}