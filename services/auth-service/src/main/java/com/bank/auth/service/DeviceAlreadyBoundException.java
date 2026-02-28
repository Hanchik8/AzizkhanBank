package com.bank.auth.service;

public class DeviceAlreadyBoundException extends RuntimeException {

    public DeviceAlreadyBoundException(String deviceId) {
        super("Device is already registered: " + deviceId);
    }
}
