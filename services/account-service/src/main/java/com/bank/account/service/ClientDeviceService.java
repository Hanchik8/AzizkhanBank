package com.bank.account.service;

import com.bank.account.domain.ClientDevice;
import com.bank.account.repository.ClientDeviceRepository;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.Signature;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.X509EncodedKeySpec;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.Base64;
import java.util.Optional;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
public class ClientDeviceService {

    private static final Duration MAX_DPOP_REQUEST_AGE = Duration.ofMinutes(5);

    private final ClientDeviceRepository clientDeviceRepository;
    private final Clock clock;

    public ClientDeviceService(ClientDeviceRepository clientDeviceRepository) {
        this.clientDeviceRepository = clientDeviceRepository;
        this.clock = Clock.systemUTC();
    }

    @Transactional
    public ClientDevice registerDevice(String userId, String deviceId, String base64PublicKey) {
        if (!StringUtils.hasText(userId)) {
            throw new IllegalArgumentException("userId is required");
        }
        if (!StringUtils.hasText(deviceId)) {
            throw new IllegalArgumentException("deviceId is required");
        }
        if (!StringUtils.hasText(base64PublicKey)) {
            throw new IllegalArgumentException("publicKey is required");
        }

        if (clientDeviceRepository.findByDeviceId(deviceId).isPresent()) {
            throw new IllegalArgumentException("Device is already registered");
        }

        PublicKey publicKey = decodeRsaPublicKey(base64PublicKey);
        String normalizedPublicKey = Base64.getEncoder().encodeToString(publicKey.getEncoded());

        ClientDevice clientDevice = ClientDevice.registered(userId.trim(), deviceId.trim(), normalizedPublicKey);
        return clientDeviceRepository.save(clientDevice);
    }

    public DpopVerificationResult verifyDpopRequest(
        String deviceIdHeader,
        String timestampHeader,
        String signatureHeader,
        String rawJsonBody
    ) {
        if (!StringUtils.hasText(deviceIdHeader)
            || !StringUtils.hasText(timestampHeader)
            || !StringUtils.hasText(signatureHeader)) {
            return DpopVerificationResult.failure(HttpStatus.UNAUTHORIZED, "Missing required DPoP headers");
        }

        Instant requestTimestamp;
        try {
            requestTimestamp = parseTimestampHeader(timestampHeader);
        } catch (IllegalArgumentException ex) {
            return DpopVerificationResult.failure(HttpStatus.BAD_REQUEST, ex.getMessage());
        }

        Instant now = Instant.now(clock);
        if (requestTimestamp.isBefore(now.minus(MAX_DPOP_REQUEST_AGE))) {
            return DpopVerificationResult.failure(HttpStatus.UNAUTHORIZED, "DPoP timestamp is older than 5 minutes");
        }

        Optional<ClientDevice> clientDeviceOptional = clientDeviceRepository.findByDeviceId(deviceIdHeader);
        if (clientDeviceOptional.isEmpty()) {
            return DpopVerificationResult.failure(HttpStatus.UNAUTHORIZED, "Unknown device");
        }

        ClientDevice clientDevice = clientDeviceOptional.get();
        String signedPayload = timestampHeader + (rawJsonBody == null ? "" : rawJsonBody);

        try {
            PublicKey publicKey = decodeRsaPublicKey(clientDevice.getPublicKey());
            boolean verified = verifySignature(signedPayload, signatureHeader, publicKey);
            if (!verified) {
                return DpopVerificationResult.failure(HttpStatus.UNAUTHORIZED, "Invalid DPoP signature");
            }
        } catch (IllegalArgumentException ex) {
            return DpopVerificationResult.failure(HttpStatus.BAD_REQUEST, ex.getMessage());
        } catch (GeneralSecurityException ex) {
            return DpopVerificationResult.failure(HttpStatus.UNAUTHORIZED, "Invalid DPoP signature");
        }

        return DpopVerificationResult.success();
    }

    private Instant parseTimestampHeader(String timestampHeader) {
        String normalizedTimestamp = timestampHeader.trim();
        try {
            return Instant.parse(normalizedTimestamp);
        } catch (DateTimeParseException ignored) {
            try {
                long epochMillis = Long.parseLong(normalizedTimestamp);
                return Instant.ofEpochMilli(epochMillis);
            } catch (NumberFormatException ex) {
                throw new IllegalArgumentException("X-Timestamp must be ISO-8601 or epoch milliseconds");
            }
        }
    }

    private PublicKey decodeRsaPublicKey(String base64PublicKey) {
        try {
            byte[] keyBytes = Base64.getDecoder().decode(base64PublicKey);
            X509EncodedKeySpec keySpec = new X509EncodedKeySpec(keyBytes);
            KeyFactory keyFactory = KeyFactory.getInstance("RSA");
            PublicKey publicKey = keyFactory.generatePublic(keySpec);
            if (!(publicKey instanceof RSAPublicKey)) {
                throw new IllegalArgumentException("publicKey must be an RSA key");
            }
            return publicKey;
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException("publicKey must be a valid Base64-encoded RSA key", ex);
        } catch (GeneralSecurityException ex) {
            throw new IllegalArgumentException("publicKey must be a valid Base64-encoded RSA key", ex);
        }
    }

    private boolean verifySignature(String payload, String base64Signature, PublicKey publicKey)
        throws GeneralSecurityException {
        byte[] signatureBytes;
        try {
            signatureBytes = Base64.getDecoder().decode(base64Signature);
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException("X-Signature must be a valid Base64 string", ex);
        }

        Signature verifier = Signature.getInstance("SHA256withRSA");
        verifier.initVerify(publicKey);
        verifier.update(payload.getBytes(StandardCharsets.UTF_8));
        return verifier.verify(signatureBytes);
    }

    public record DpopVerificationResult(boolean valid, HttpStatus status, String message) {

        static DpopVerificationResult success() {
            return new DpopVerificationResult(true, HttpStatus.OK, "OK");
        }

        static DpopVerificationResult failure(HttpStatus status, String message) {
            return new DpopVerificationResult(false, status, message);
        }
    }
}
