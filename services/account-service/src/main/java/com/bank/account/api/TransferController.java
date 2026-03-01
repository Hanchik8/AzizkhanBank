package com.bank.account.api;

import java.net.URI;
import java.time.Instant;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.bank.account.service.AccountTransferService;
import com.bank.account.service.TransferCommand;
import com.bank.account.service.TransferResult;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;

@RestController
@RequestMapping("/api/v1/transfers")
@Validated
public class TransferController {

    private final AccountTransferService accountTransferService;

    public TransferController(AccountTransferService accountTransferService) {
        this.accountTransferService = accountTransferService;
    }

    @PostMapping
    public ResponseEntity<TransferFundsResponse> transferFunds(
        @AuthenticationPrincipal Jwt jwt,
        @RequestHeader(name = "Idempotency-Key") @NotBlank String idempotencyKey,
        @Valid @RequestBody TransferFundsRequest request
    ) {
        String userId = resolveUserId(jwt);
        TransferCommand command = new TransferCommand(
            userId,
            idempotencyKey,
            request.fromAccountId(),
            request.toAccountId(),
            request.amount(),
            request.currency(),
            Instant.now()
        );

        TransferResult result = accountTransferService.transfer(command);
        TransferFundsResponse response = TransferFundsResponse.from(result);

        if (result.idempotentReplay()) {
            return ResponseEntity.ok(response);
        }

        URI location = URI.create("/api/v1/transfers/" + result.transferId());
        return ResponseEntity.created(location).body(response);
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
