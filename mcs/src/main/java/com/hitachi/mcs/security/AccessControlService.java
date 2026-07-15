package com.hitachi.mcs.security;

import com.hitachi.mcs.entity.Bill;
import com.hitachi.mcs.entity.Transaction;
import com.hitachi.mcs.repository.BillRepository;
import com.hitachi.mcs.repository.CustomerRepository;
import com.hitachi.mcs.repository.MerchantRepository;
import com.hitachi.mcs.repository.TransactionRepository;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

@Service("accessControlService")
public class AccessControlService {
    private final MerchantRepository merchantRepository;
    private final CustomerRepository customerRepository;
    private final BillRepository billRepository;
    private final TransactionRepository transactionRepository;

    public AccessControlService(MerchantRepository merchantRepository,
                                CustomerRepository customerRepository,
                                BillRepository billRepository,
                                TransactionRepository transactionRepository) {
        this.merchantRepository = merchantRepository;
        this.customerRepository = customerRepository;
        this.billRepository = billRepository;
        this.transactionRepository = transactionRepository;
    }

    public boolean isMerchant(Authentication authentication, Long merchantId) {
        return isAuthenticated(authentication) && hasRole(authentication, "MERCHANT")
                && merchantRepository.findByEmail(authentication.getName())
                .map(merchant -> merchant.getId().equals(merchantId)).orElse(false);
    }

    public boolean isCustomer(Authentication authentication, Long customerId) {
        return isAuthenticated(authentication) && hasRole(authentication, "CUSTOMER")
                && customerRepository.findByEmail(authentication.getName())
                .map(customer -> customer.getId().equals(customerId)).orElse(false);
    }

    public boolean ownsBill(Authentication authentication, Long billId) {
        return isAuthenticated(authentication) && billRepository.findById(billId)
                .map(bill -> ownsBill(authentication, bill)).orElse(false);
    }

    public boolean ownsTransaction(Authentication authentication, Long transactionId) {
        return isAuthenticated(authentication) && transactionRepository.findById(transactionId)
                .map(transaction -> ownsBill(authentication, transaction)).orElse(false);
    }

    private boolean ownsBill(Authentication authentication, Transaction transaction) {
        return ownsBill(authentication, transaction.getBill());
    }

    private boolean ownsBill(Authentication authentication, Bill bill) {
        String email = authentication.getName();
        if (hasRole(authentication, "MERCHANT")) {
            return bill.getMerchant().getEmail().equalsIgnoreCase(email);
        }
        if (hasRole(authentication, "CUSTOMER")) {
            return bill.getCustomer().getEmail().equalsIgnoreCase(email);
        }
        return false;
    }

    private boolean isAuthenticated(Authentication authentication) {
        return authentication != null && authentication.isAuthenticated();
    }

    private boolean hasRole(Authentication authentication, String role) {
        return authentication.getAuthorities().stream()
                .anyMatch(authority -> authority.getAuthority().equals("ROLE_" + role));
    }
}
