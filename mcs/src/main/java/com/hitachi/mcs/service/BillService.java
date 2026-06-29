package com.hitachi.mcs.service;

import com.hitachi.mcs.dto.BillRequest;
import com.hitachi.mcs.dto.BillResponse;
import com.hitachi.mcs.entity.Bill;
import com.hitachi.mcs.entity.Customer;
import com.hitachi.mcs.entity.Merchant;
import com.hitachi.mcs.repository.BillRepository;
import com.hitachi.mcs.repository.CustomerRepository;
import com.hitachi.mcs.repository.MerchantRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class BillService {

    private final BillRepository billRepository;
    private final MerchantRepository merchantRepository;
    private final CustomerRepository customerRepository;

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
        response.setCreatedAt(bill.getCreatedAt());
        response.setUpdatedAt(bill.getUpdatedAt());

        return response;
    }
}