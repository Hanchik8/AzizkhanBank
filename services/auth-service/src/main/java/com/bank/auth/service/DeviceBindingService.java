package com.bank.auth.service;

import java.util.UUID;
import org.springframework.stereotype.Service;

@Service
public class DeviceBindingService {

    private final JwtService jwtService;
    private final ClientDeviceService clientDeviceService;

    public DeviceBindingService(JwtService jwtService, ClientDeviceService clientDeviceService) {
        this.jwtService = jwtService;
        this.clientDeviceService = clientDeviceService;
    }

    public JwtService.TokenPair bindDevice(String authorizationHeader, String deviceId, String publicKey) {
        UUID userId = jwtService.requireRegistrationUserId(authorizationHeader);
        clientDeviceService.registerDevice(userId.toString(), deviceId, publicKey);
        return jwtService.generateFinalTokenPair(userId, deviceId);
    }
}
