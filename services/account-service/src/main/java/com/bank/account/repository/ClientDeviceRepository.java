package com.bank.account.repository;

import com.bank.account.domain.ClientDevice;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ClientDeviceRepository extends JpaRepository<ClientDevice, UUID> {

    Optional<ClientDevice> findByDeviceId(String deviceId);
}
