package com.truenorth119.api;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AccountUserRepository extends JpaRepository<AccountUser, Long> {
    Optional<AccountUser> findByAuthIssuerAndAuthSubject(String issuer, String subject);
}
