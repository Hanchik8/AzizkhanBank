package com.bank.auth.service;

import com.bank.auth.domain.ClientDevice;
import com.bank.auth.repository.ClientDeviceRepository;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.interfaces.RSAPublicKey;
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

        PublicKey publicKey = decodeRsaPublicKey(base64PublicKey);
        String normalizedPublicKey = Base64.getEncoder().encodeToString(publicKey.getEncoded());

        ClientDevice clientDevice = ClientDevice.registered(userId.trim(), normalizedDeviceId, normalizedPublicKey);
        return clientDeviceRepository.save(clientDevice);
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
}
