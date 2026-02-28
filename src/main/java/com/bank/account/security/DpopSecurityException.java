package com.bank.account.security;

import org.springframework.http.HttpStatus;

public class DpopSecurityException extends RuntimeException {

    private final HttpStatus status;

    public DpopSecurityException(HttpStatus status, String message) {
        super(message);
        this.status = status;
    }

    public HttpStatus getStatus() {
        return status;
    }
}
