package com.bank.auth.service;

import com.bank.auth.domain.ClientDevice;
import com.bank.auth.repository.ClientDeviceRepository;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
public class ClientDeviceService {

    private final ClientDeviceRepository clientDeviceRepository;

    public ClientDeviceService(ClientDeviceRepository clientDeviceRepository) {
        this.clientDeviceRepository = clientDeviceRepository;
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

        String normalizedDeviceId = deviceId.trim();
        if (clientDeviceRepository.findByDeviceId(normalizedDeviceId).isPresent()) {
            throw new DeviceAlreadyBoundException(normalizedDeviceId);
        }

        PublicKey publicKey = decodePublicKey(base64PublicKey);
        String normalizedPublicKey = Base64.getEncoder().encodeToString(publicKey.getEncoded());

        ClientDevice clientDevice = ClientDevice.registered(userId.trim(), normalizedDeviceId, normalizedPublicKey);
        return clientDeviceRepository.save(clientDevice);
    }

    private PublicKey decodePublicKey(String publicKeyInput) {
        try {
            // Strip PEM headers and all whitespace if the key is in PEM format
            String base64 = publicKeyInput
                .replaceAll("-----BEGIN[^-]*-----", "")
                .replaceAll("-----END[^-]*-----", "")
                .replaceAll("\\s+", "");

            byte[] keyBytes = Base64.getDecoder().decode(base64);
            X509EncodedKeySpec keySpec = new X509EncodedKeySpec(keyBytes);

            // Try EC first (DPoP / Flutter uses P-256), fall back to RSA
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
}
