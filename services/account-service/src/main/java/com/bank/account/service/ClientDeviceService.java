package com.bank.account.service;

import com.bank.account.domain.ClientDevice;
import com.bank.account.repository.ClientDeviceRepository;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.Signature;
import java.security.interfaces.ECPublicKey;
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

        PublicKey publicKey = decodePublicKey(base64PublicKey);
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
            PublicKey publicKey = decodePublicKey(clientDevice.getPublicKey());
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

    // Supports both EC and RSA public keys, with or without PEM headers
    private PublicKey decodePublicKey(String publicKeyInput) {
        try {
            String base64 = publicKeyInput
                .replaceAll("-----BEGIN[^-]*-----", "")
                .replaceAll("-----END[^-]*-----", "")
                .replaceAll("\\s+", "");
            byte[] keyBytes = Base64.getDecoder().decode(base64);
            X509EncodedKeySpec keySpec = new X509EncodedKeySpec(keyBytes);

            for (String algorithm : new String[]{"EC", "RSA"}) {
                try {
                    return KeyFactory.getInstance(algorithm).generatePublic(keySpec);
                } catch (GeneralSecurityException ignored) {
                    // try next algorithm
                }
            }
            throw new IllegalArgumentException("publicKey must be a valid EC or RSA public key");
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException("publicKey must be a valid Base64-encoded public key", ex);
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

        // Use ECDSA for EC keys, RSA for RSA keys
        String algorithm = (publicKey instanceof ECPublicKey) ? "SHA256withECDSA" : "SHA256withRSA";
        Signature verifier = Signature.getInstance(algorithm);
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
