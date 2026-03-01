package com.bank.account.api;

import java.util.List;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.bank.account.service.AccountQueryService;

@RestController
@RequestMapping("/api/v1/accounts")
public class AccountQueryController {

    private final AccountQueryService accountQueryService;

    public AccountQueryController(AccountQueryService accountQueryService) {
        this.accountQueryService = accountQueryService;
    }

    @GetMapping("")
    public List<AccountResponse> getUserAccounts(@AuthenticationPrincipal Jwt jwt) {
        String userId = resolveUserId(jwt);
        return accountQueryService.getUserAccounts(userId);
    }

    @GetMapping("/{id}/history")
    public List<TransactionHistoryResponse> getAccountHistory(
        @PathVariable Long id,
        @AuthenticationPrincipal Jwt jwt
    ) {
        String userId = resolveUserId(jwt);
        return accountQueryService.getAccountHistory(userId, id);
    }

    private String resolveUserId(Jwt jwt) {
        if (jwt == null) {
            throw new IllegalArgumentException("Authenticated JWT is required");
        }

        String subject = jwt.getSubject();
        if (subject == null || subject.isBlank()) {
            throw new IllegalArgumentException("JWT subject (userId) is required");
        }

        return subject;
    }
}
