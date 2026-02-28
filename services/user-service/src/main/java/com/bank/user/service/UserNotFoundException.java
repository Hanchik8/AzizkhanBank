package com.bank.user.service;

public class UserNotFoundException extends RuntimeException {

    public UserNotFoundException(String phoneNumber) {
        super("User with phone number '" + phoneNumber + "' was not found");
    }
}
