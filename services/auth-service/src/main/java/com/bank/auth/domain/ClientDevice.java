package com.bank.auth.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(
    name = "client_devices",
    uniqueConstraints = @UniqueConstraint(name = "uk_client_devices_device_id", columnNames = "device_id")
)
public class ClientDevice {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false, length = 128)
    private String userId;

    @Column(name = "device_id", nullable = false, length = 128)
    private String deviceId;

    @Column(name = "public_key", nullable = false, length = 4096)
    private String publicKey;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected ClientDevice() {
    }

    private ClientDevice(String userId, String deviceId, String publicKey) {
        this.userId = userId;
        this.deviceId = deviceId;
        this.publicKey = publicKey;
        this.createdAt = Instant.now();
    }

    public static ClientDevice registered(String userId, String deviceId, String publicKey) {
        return new ClientDevice(userId, deviceId, publicKey);
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }

    public UUID getId() {
        return id;
    }

    public String getUserId() {
        return userId;
    }

    public String getDeviceId() {
        return deviceId;
    }

    public String getPublicKey() {
        return publicKey;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
