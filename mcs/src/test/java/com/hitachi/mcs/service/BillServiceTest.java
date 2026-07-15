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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BillServiceTest {
    @Mock private BillRepository billRepository;
    @Mock private MerchantRepository merchantRepository;
    @Mock private CustomerRepository customerRepository;
    private BillService service;
    private Merchant merchant;
    private Customer customer;

    @BeforeEach
    void setUp() {
        service = new BillService(billRepository, merchantRepository, customerRepository);
        merchant = new Merchant();
        merchant.setId(1L);
        merchant.setName("Merchant");
        customer = new Customer();
        customer.setId(2L);
        customer.setName("Customer");
    }

    @Test
    void createsPendingBillForSpecifiedMerchantAndCustomer() {
        BillRequest request = new BillRequest();
        request.setMerchantId(1L);
        request.setCustomerId(2L);
        request.setAmount(new BigDecimal("999.00"));
        request.setDescription("Invoice");
        when(merchantRepository.findById(1L)).thenReturn(Optional.of(merchant));
        when(customerRepository.findById(2L)).thenReturn(Optional.of(customer));
        when(billRepository.save(any(Bill.class))).thenAnswer(invocation -> {
            Bill bill = invocation.getArgument(0);
            bill.setId(10L);
            return bill;
        });

        BillResponse result = service.createBill(request);

        assertThat(result.getId()).isEqualTo(10L);
        assertThat(result.getStatus()).isEqualTo("PENDING");
        assertThat(result.getAmount()).isEqualByComparingTo("999.00");
        assertThat(result.getMerchantId()).isEqualTo(1L);
        assertThat(result.getCustomerId()).isEqualTo(2L);
    }

    @Test
    void refusesRefundWhenBillIsNotPaid() {
        Bill pending = bill("PENDING");
        when(billRepository.findById(10L)).thenReturn(Optional.of(pending));

        assertThatThrownBy(() -> service.refundBill(10L, new RefundRequest()))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Only paid bills can be refunded");
    }

    @Test
    void recordsRefundReasonAndTimestampForPaidBill() {
        Bill paid = bill("PAID");
        RefundRequest request = new RefundRequest();
        request.setReason("Duplicate payment");
        when(billRepository.findById(10L)).thenReturn(Optional.of(paid));
        when(billRepository.save(paid)).thenReturn(paid);

        BillResponse result = service.refundBill(10L, request);

        assertThat(result.getStatus()).isEqualTo("REFUNDED");
        assertThat(result.getRefundReason()).isEqualTo("Duplicate payment");
        assertThat(result.getRefundedAt()).isNotNull();
    }

    private Bill bill(String status) {
        Bill bill = new Bill();
        bill.setId(10L);
        bill.setMerchant(merchant);
        bill.setCustomer(customer);
        bill.setAmount(new BigDecimal("100.00"));
        bill.setStatus(status);
        return bill;
    }
}
