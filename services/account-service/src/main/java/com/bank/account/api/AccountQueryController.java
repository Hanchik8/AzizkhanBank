package com.bank.account.api;

import java.util.List;

import org.springframework.data.domain.Page;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
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
        return accountQueryService.getUserAccounts(JwtUtils.requireUserId(jwt));
    }

    @GetMapping("/{id}/history")
    public Page<TransactionHistoryResponse> getAccountHistory(
        @PathVariable Long id,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "50") int size,
        @AuthenticationPrincipal Jwt jwt
    ) {
        return accountQueryService.getAccountHistory(JwtUtils.requireUserId(jwt), id, page, size);
    }
}
