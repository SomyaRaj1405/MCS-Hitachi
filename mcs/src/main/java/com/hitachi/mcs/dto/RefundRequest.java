package com.hitachi.mcs.dto;

import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class RefundRequest {
    @Size(max = 255, message = "Refund reason cannot exceed 255 characters")
    private String reason;
}
