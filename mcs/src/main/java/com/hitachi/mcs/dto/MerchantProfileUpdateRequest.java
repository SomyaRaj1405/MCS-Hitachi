package com.hitachi.mcs.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class MerchantProfileUpdateRequest {

    @NotBlank(message = "Name is required")
    @Size(min = 2, max = 100, message = "Name must be between 2 and 100 characters")
    private String name;

    @NotBlank(message = "Email is required")
    @Email(message = "Email must be valid")
    private String email;

    @Size(max = 150, message = "Business name must be at most 150 characters")
    private String businessName;

    @Pattern(regexp = "^$|^[0-9]{10}$", message = "Phone must be exactly 10 digits")
    private String phone;
}
