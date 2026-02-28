package com.bank.auth.service;

import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.Objects;
import java.util.UUID;
import javax.crypto.SecretKey;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
public class JwtService {

    private final SecretKey signingKey;
    private final Duration registrationExpiration;
    private final Duration accessExpiration;
    private final Duration refreshExpiration;

    public JwtService(
        @Value("${auth.jwt.secret}") String secret,
        @Value("${auth.jwt.registration-expiration-minutes:10}") long registrationExpirationMinutes,
        @Value("${auth.jwt.access-expiration-minutes:15}") long accessExpirationMinutes,
        @Value("${auth.jwt.refresh-expiration-minutes:43200}") long refreshExpirationMinutes
    ) {
        this.signingKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.registrationExpiration = Duration.ofMinutes(registrationExpirationMinutes);
        this.accessExpiration = Duration.ofMinutes(accessExpirationMinutes);
        this.refreshExpiration = Duration.ofMinutes(refreshExpirationMinutes);
    }

    public String generateRegistrationToken(UUID userId) {
        Instant now = Instant.now();
        Instant expiresAt = now.plus(registrationExpiration);

        return Jwts.builder()
            .subject(userId.toString())
            .claim("role", "REGISTRATION")
            .claim("userId", userId.toString())
            .issuedAt(Date.from(now))
            .expiration(Date.from(expiresAt))
            .signWith(signingKey, Jwts.SIG.HS256)
            .compact();
    }

    public TokenPair generateFinalTokenPair(UUID userId) {
        String accessToken = generateToken(userId, "ACCESS", accessExpiration);
        String refreshToken = generateToken(userId, "REFRESH", refreshExpiration);
        return new TokenPair(accessToken, refreshToken);
    }

    public UUID requireRegistrationUserId(String authorizationHeader) {
        String token = extractBearerToken(authorizationHeader);
        try {
            var claims = Jwts.parser()
                .verifyWith(signingKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();

            String role = claims.get("role", String.class);
            if (!Objects.equals("REGISTRATION", role)) {
                throw new ForbiddenException("Token role REGISTRATION is required");
            }

            String userIdClaim = claims.get("userId", String.class);
            if (!StringUtils.hasText(userIdClaim)) {
                userIdClaim = claims.getSubject();
            }
            if (!StringUtils.hasText(userIdClaim)) {
                throw new UnauthorizedException("Token does not contain userId");
            }

            return UUID.fromString(userIdClaim);
        } catch (IllegalArgumentException ex) {
            throw new UnauthorizedException("Invalid token payload");
        } catch (JwtException ex) {
            throw new UnauthorizedException("Invalid or expired token");
        }
    }

    private String extractBearerToken(String authorizationHeader) {
        if (!StringUtils.hasText(authorizationHeader)) {
            throw new UnauthorizedException("Authorization header is required");
        }
        if (!authorizationHeader.startsWith("Bearer ")) {
            throw new UnauthorizedException("Authorization header must use Bearer scheme");
        }

        String token = authorizationHeader.substring("Bearer ".length()).trim();
        if (!StringUtils.hasText(token)) {
            throw new UnauthorizedException("Bearer token is empty");
        }

        return token;
    }

    private String generateToken(UUID userId, String tokenType, Duration ttl) {
        Instant now = Instant.now();
        Instant expiresAt = now.plus(ttl);

        return Jwts.builder()
            .subject(userId.toString())
            .claim("userId", userId.toString())
            .claim("tokenType", tokenType)
            .issuedAt(Date.from(now))
            .expiration(Date.from(expiresAt))
            .signWith(signingKey, Jwts.SIG.HS256)
            .compact();
    }

    public record TokenPair(String accessToken, String refreshToken) {
    }
}
