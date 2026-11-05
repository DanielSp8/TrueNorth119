-- Model:
--   users        - user profiles; login/authentication is managed separately
--   themes       - owned Scripture collections (one owner per theme)
--   verses       - Scripture references attached to a theme
--   theme_shares - permission grants to other users (viewer/editor)
--
-- Sharing a theme grants access to its verses. Nothing is copied.
-- IMPORTANT: FOREIGN KEYS DO NOT ENFORCE USER ACCESS/PERMISSIONS.
-- Enforce ownership, viewing, editing, and share management in your backend.
-- This design assumes a trusted backend talks to MySQL; do not grant end users
-- direct, unrestricted access to these tables.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS truenorth119
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE truenorth119;

-- drop table if exists users, ...;
-- add tables to drop on the line above...

-- 1. Registered users -------------------------------------------------------
CREATE TABLE users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uq_users_username UNIQUE (username),
    CONSTRAINT chk_users_username
        CHECK (CHAR_LENGTH(username) >= 3 AND username = TRIM(username))
) ENGINE=InnoDB;

-- 2. Personally owned Scripture themes -------------------------------------
CREATE TABLE themes (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_user_id BIGINT UNSIGNED NOT NULL,
    title VARCHAR(150) NOT NULL,
    description TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uq_themes_owner_title UNIQUE (owner_user_id, title),
    CONSTRAINT fk_themes_owner FOREIGN KEY (owner_user_id)
        REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT chk_themes_title
        CHECK (CHAR_LENGTH(title) > 0 AND title = TRIM(title))
) ENGINE=InnoDB;

-- 3. Scripture references in a theme ---------------------------------------
CREATE TABLE verses (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    theme_id BIGINT UNSIGNED NOT NULL,
    address VARCHAR(100) NOT NULL,  -- e.g., 'Romans 8:28' or 'Psalm 119:9-11'
    notes TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uq_verses_theme_address UNIQUE (theme_id, address),
    CONSTRAINT fk_verses_theme FOREIGN KEY (theme_id)
        REFERENCES themes (id) ON DELETE CASCADE,
    CONSTRAINT chk_verses_address
        CHECK (CHAR_LENGTH(address) > 0 AND address = TRIM(address))
) ENGINE=InnoDB;

-- 4. Shares of a theme with individual users -------------------------------
CREATE TABLE theme_shares (
    theme_id BIGINT UNSIGNED NOT NULL,
    shared_with_user_id BIGINT UNSIGNED NOT NULL,
    permission ENUM('viewer', 'editor') NOT NULL DEFAULT 'viewer',
    shared_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (theme_id, shared_with_user_id),
    INDEX idx_theme_shares_recipient (shared_with_user_id, theme_id),
    CONSTRAINT fk_theme_shares_theme FOREIGN KEY (theme_id)
        REFERENCES themes (id) ON DELETE CASCADE,
    CONSTRAINT fk_theme_shares_recipient FOREIGN KEY (shared_with_user_id)
        REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Prevent sharing a theme with its owner. Requires multiple-statement triggers;
-- DELIMITER is supported in MySQL Workbench's script editor.
DELIMITER $$

CREATE TRIGGER trg_theme_shares_no_self_insert
BEFORE INSERT ON theme_shares
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM themes
        WHERE id = NEW.theme_id
          AND owner_user_id = NEW.shared_with_user_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A theme cannot be shared with its owner';
    END IF;
END$$

CREATE TRIGGER trg_theme_shares_no_self_update
BEFORE UPDATE ON theme_shares
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM themes
        WHERE id = NEW.theme_id
          AND owner_user_id = NEW.shared_with_user_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A theme cannot be shared with its owner';
    END IF;
END$$

-- Ownership transfers aren't part of the current application. Protect the
-- self-share invariant if an owner_user_id is changed directly later.
CREATE TRIGGER trg_themes_no_invalid_owner_change
BEFORE UPDATE ON themes
FOR EACH ROW
BEGIN
    IF NEW.owner_user_id <> OLD.owner_user_id AND EXISTS (
        SELECT 1 FROM theme_shares
        WHERE theme_id = OLD.id
          AND shared_with_user_id = NEW.owner_user_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Revoke existing share before changing owner';
    END IF;
END$$

DELIMITER ;
