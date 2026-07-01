package com.hitachi.mcs.controller;
import java.util.Map;
import com.hitachi.mcs.dto.LoginRequest;
import com.hitachi.mcs.dto.LoginResponse;
import com.hitachi.mcs.dto.RegisterRequest;
import com.hitachi.mcs.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register")
    public ResponseEntity<Map<String, String>> register(@Valid @RequestBody RegisterRequest request) {
        String message = authService.register(request);
        return ResponseEntity.ok(Map.of("message", message));
    }

    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(@Valid @RequestBody LoginRequest request) {
        LoginResponse response = authService.login(request);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/me")
    public ResponseEntity<?> getCurrentUser(@RequestHeader("Authorization") String authHeader) {
        try {
            String token = authHeader.replace("Bearer ", "");
            String email = authService.getEmailFromToken(token);
            String role = authService.getRoleFromToken(token);
            return ResponseEntity.ok(authService.getUserInfo(email, role));
        } catch (Exception e) {
            return ResponseEntity.status(401).body("Invalid token");
        }
    }
}