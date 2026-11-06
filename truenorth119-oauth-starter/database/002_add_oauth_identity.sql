-- Run this ONCE in MySQL Workbench AFTER your original v3 MySQL schema.
-- Existing rows can remain null until you migrate/link them to real accounts.
USE truenorth119;

ALTER TABLE users
  ADD COLUMN auth_issuer VARCHAR(255) NULL,
  ADD COLUMN auth_subject VARCHAR(255) NULL,
  ADD CONSTRAINT uq_users_oauth_identity UNIQUE (auth_issuer, auth_subject);

-- Production: after linking legacy users, consider making both columns NOT NULL.
-- Do NOT store OAuth tokens, passwords, or client secrets in users.
