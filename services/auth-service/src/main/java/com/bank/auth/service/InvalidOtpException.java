package com.bank.auth.service;

public class InvalidOtpException extends RuntimeException {

    public InvalidOtpException() {
        super("Invalid phone number or OTP code");
    }
}
