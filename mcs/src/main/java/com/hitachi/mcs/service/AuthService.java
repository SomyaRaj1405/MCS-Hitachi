package com.hitachi.mcs.service;

import com.hitachi.mcs.dto.LoginRequest;
import com.hitachi.mcs.dto.LoginResponse;
import com.hitachi.mcs.dto.RegisterRequest;
import com.hitachi.mcs.dto.MerchantProfileUpdateRequest;
import com.hitachi.mcs.entity.Customer;
import com.hitachi.mcs.entity.Merchant;
import com.hitachi.mcs.repository.CustomerRepository;
import com.hitachi.mcs.repository.MerchantRepository;
import com.hitachi.mcs.security.JwtUtil;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import java.util.HashMap;
import java.util.Map;

@Service
public class AuthService {

    @Autowired
    private MerchantRepository merchantRepository;

    @Autowired
    private CustomerRepository customerRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtUtil jwtUtil;

    public String register(RegisterRequest request) {
        if (request.getRole().equalsIgnoreCase("MERCHANT")) {
            if (merchantRepository.existsByEmail(request.getEmail())) {
                throw new RuntimeException("Merchant email already exists");
            }
            Merchant merchant = new Merchant();
            merchant.setName(request.getName());
            merchant.setEmail(request.getEmail());
            merchant.setPasswordHash(passwordEncoder.encode(request.getPassword()));
            merchant.setPhone(request.getPhone());
            merchantRepository.save(merchant);
            return "Merchant registered successfully";
        } else {
            if (customerRepository.existsByEmail(request.getEmail())) {
                throw new RuntimeException("Customer email already exists");
            }
            Customer customer = new Customer();
            customer.setName(request.getName());
            customer.setEmail(request.getEmail());
            customer.setPasswordHash(passwordEncoder.encode(request.getPassword()));
            customer.setPhone(request.getPhone());
            customerRepository.save(customer);
            return "Customer registered successfully";
        }
    }

    public LoginResponse login(LoginRequest request) {
        if (request.getRole().equalsIgnoreCase("MERCHANT")) {
            Merchant merchant = merchantRepository.findByEmail(request.getEmail())
                    .orElseThrow(() -> new RuntimeException("Merchant not found"));
            if (!passwordEncoder.matches(request.getPassword(), merchant.getPasswordHash())) {
                throw new RuntimeException("Invalid password");
            }
            String token = jwtUtil.generateToken(merchant.getEmail(), "MERCHANT");
            return new LoginResponse(token, "MERCHANT", merchant.getEmail());
        } else {
            Customer customer = customerRepository.findByEmail(request.getEmail())
                    .orElseThrow(() -> new RuntimeException("Customer not found"));
            if (!passwordEncoder.matches(request.getPassword(), customer.getPasswordHash())) {
                throw new RuntimeException("Invalid password");
            }
            String token = jwtUtil.generateToken(customer.getEmail(), "CUSTOMER");
            return new LoginResponse(token, "CUSTOMER", customer.getEmail());
        }
    }

    public String getEmailFromToken(String token) {
        return jwtUtil.extractEmail(token);
    }

    public String getRoleFromToken(String token) {
        return jwtUtil.extractRole(token);
    }

    public Object getUserInfo(String email, String role) {
        if (role.equalsIgnoreCase("MERCHANT")) {
            Merchant merchant = merchantRepository.findByEmail(email)
                    .orElseThrow(() -> new RuntimeException("Merchant not found"));
            return new java.util.HashMap<String, Object>() {{
                put("id", merchant.getId());
                put("name", merchant.getName());
                put("email", merchant.getEmail());
                put("phone", merchant.getPhone() == null ? "" : merchant.getPhone());
                put("role", "MERCHANT");
            }};
        } else {
            Customer customer = customerRepository.findByEmail(email)
                    .orElseThrow(() -> new RuntimeException("Customer not found"));
            return new java.util.HashMap<String, Object>() {{
                put("id", customer.getId());
                put("name", customer.getName());
                put("email", customer.getEmail());
                put("role", "CUSTOMER");
            }};
        }
    }

    public Map<String, Object> updateMerchantProfile(
            String currentEmail,
            String role,
            MerchantProfileUpdateRequest request) {
        if (!"MERCHANT".equalsIgnoreCase(role)) {
            throw new RuntimeException("Only merchant profiles can be updated here");
        }

        Merchant merchant = merchantRepository.findByEmail(currentEmail)
                .orElseThrow(() -> new RuntimeException("Merchant not found"));
        String newEmail = request.getEmail().trim().toLowerCase();
        if (merchantRepository.existsByEmailAndIdNot(newEmail, merchant.getId())) {
            throw new RuntimeException("Merchant email already exists");
        }

        merchant.setName(request.getName().trim());
        merchant.setEmail(newEmail);
        merchant.setPhone(normalizeOptional(request.getPhone()));
        Merchant saved = merchantRepository.save(merchant);

        Map<String, Object> response = new HashMap<>();
        response.put("id", saved.getId());
        response.put("name", saved.getName());
        response.put("email", saved.getEmail());
        response.put("phone", saved.getPhone() == null ? "" : saved.getPhone());
        response.put("role", "MERCHANT");
        response.put("token", jwtUtil.generateToken(saved.getEmail(), "MERCHANT"));
        return response;
    }

    private String normalizeOptional(String value) {
        if (value == null || value.trim().isEmpty()) return null;
        return value.trim();
    }
}
