package com.bank.account.api;

import com.bank.account.domain.ClientDevice;
import com.bank.account.service.ClientDeviceService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.net.URI;
import java.time.Instant;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/devices")
@Validated
public class ClientDeviceController {

    private final ClientDeviceService clientDeviceService;

    public ClientDeviceController(ClientDeviceService clientDeviceService) {
        this.clientDeviceService = clientDeviceService;
    }

    @PostMapping
    public ResponseEntity<DeviceRegistrationResponse> registerDevice(
        @AuthenticationPrincipal Jwt jwt,
        @Valid @RequestBody DeviceRegistrationRequest request
    ) {
        ClientDevice clientDevice = clientDeviceService.registerDevice(
            JwtUtils.requireUserId(jwt),
            request.deviceId(),
            request.publicKey()
        );

        URI location = URI.create("/api/v1/devices/" + clientDevice.getId());
        return ResponseEntity.created(location).body(DeviceRegistrationResponse.from(clientDevice));
    }

    public record DeviceRegistrationRequest(
        @NotBlank String deviceId,
        @NotBlank String publicKey
    ) {
    }

    public record DeviceRegistrationResponse(
        UUID id,
        String userId,
        String deviceId,
        Instant createdAt
    ) {

        public static DeviceRegistrationResponse from(ClientDevice clientDevice) {
            return new DeviceRegistrationResponse(
                clientDevice.getId(),
                clientDevice.getUserId(),
                clientDevice.getDeviceId(),
                clientDevice.getCreatedAt()
            );
        }
    }
}
