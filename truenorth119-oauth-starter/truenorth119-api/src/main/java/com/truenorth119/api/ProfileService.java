package com.truenorth119.api;

import java.util.UUID;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ProfileService {
    private final AccountUserRepository users;

    public ProfileService(AccountUserRepository users) {
        this.users = users;
    }

    @Transactional
    public AccountUser getOrCreate(Jwt jwt) {
        String issuer = jwt.getIssuer().toString();
        String subject = jwt.getSubject();
        return users.findByAuthIssuerAndAuthSubject(issuer, subject)
            .orElseGet(() -> {
                // Placeholder username. Add a proper onboarding/username-choice flow.
                String name = "tn_" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);
                return users.save(new AccountUser(name, issuer, subject));
            });
        // For concurrent first-login requests, add an upsert/retry around uniqueness.
    }
}
