package com.bank.user.service;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.bank.user.domain.User;
import com.bank.user.repository.UserRepository;

@Service
public class UserService {

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Transactional
    public User createByPhoneNumber(String phoneNumber) {
        String normalizedPhone = normalizePhone(phoneNumber);
        if (userRepository.existsByPhoneNumber(normalizedPhone)) {
            throw new PhoneNumberAlreadyExistsException(normalizedPhone);
        }

        return userRepository.save(User.created(normalizedPhone));
    }

    @Transactional(readOnly = true)
    public User findByPhoneNumber(String phoneNumber) {
        String normalizedPhone = normalizePhone(phoneNumber);
        return userRepository.findByPhoneNumber(normalizedPhone)
            .orElseThrow(() -> new UserNotFoundException(normalizedPhone));
    }

    private String normalizePhone(String phoneNumber) {
        return phoneNumber.trim();
    }
}
