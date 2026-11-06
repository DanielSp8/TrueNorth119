package com.truenorth119.api;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "users")
public class AccountUser {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 50)
    private String username;

    @Column(name = "auth_issuer", length = 255)
    private String authIssuer;

    @Column(name = "auth_subject", length = 255)
    private String authSubject;

    protected AccountUser() { }

    public AccountUser(String username, String authIssuer, String authSubject) {
        this.username = username;
        this.authIssuer = authIssuer;
        this.authSubject = authSubject;
    }

    public Long getId() { return id; }
    public String getUsername() { return username; }
}
