-- ============================================================================
-- TrueNorth119 | MySQL database schema | Version 3
-- Target: MySQL Server 8.0.16+ (including MySQL 8.4), via MySQL Workbench
--
-- FRESH DATABASE SETUP: This creates a new schema and its tables. It is NOT a
-- migration from the earlier PostgreSQL schema or any existing MySQL tables.
-- Do not rerun against an existing TrueNorth119 installation without planning
-- a migration/backing up your data first.
--
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

-- ============================================================================
-- EXAMPLE QUERIES (commented out; run individually after schema setup)
-- ============================================================================

-- Add two user profiles:
-- INSERT INTO users (username) VALUES ('alex'), ('jordan');

-- Create a theme owned by user 1:
-- INSERT INTO themes (owner_user_id, title, description)
-- VALUES (1, 'Faith', 'Bible references about trusting God');
-- SELECT LAST_INSERT_ID() AS new_theme_id;

-- Add a reference to theme 1:
-- INSERT INTO verses (theme_id, address, notes)
-- VALUES (1, 'Hebrews 11:1', 'Faith is confidence in what we hope for');

-- Share theme 1 with user 2 as a viewer (the backend MUST confirm user 1
-- is the signed-in owner; this SQL conditions the insert on ownership):
-- INSERT INTO theme_shares (theme_id, shared_with_user_id, permission)
-- SELECT t.id, 2, 'viewer'
-- FROM themes AS t
-- WHERE t.id = 1 AND t.owner_user_id = 1;

-- Give user 2 editor permissions, but only if user 1 owns the theme:
-- UPDATE theme_shares AS s
-- JOIN themes AS t ON t.id = s.theme_id
-- SET s.permission = 'editor'
-- WHERE s.theme_id = 1
--   AND s.shared_with_user_id = 2
--   AND t.owner_user_id = 1;

-- List themes owned by or shared with user 2:
-- SELECT t.id, t.title, t.owner_user_id,
--        CASE WHEN t.owner_user_id = 2 THEN 'owner'
--             ELSE s.permission END AS my_access
-- FROM themes AS t
-- LEFT JOIN theme_shares AS s
--   ON s.theme_id = t.id AND s.shared_with_user_id = 2
-- WHERE t.owner_user_id = 2 OR s.shared_with_user_id IS NOT NULL
-- ORDER BY t.title;

-- List the verses in theme 1 only when user 2 is the owner or a recipient:
-- SELECT v.id, v.address, v.notes
-- FROM verses AS v
-- JOIN themes AS t ON t.id = v.theme_id
-- WHERE t.id = 1
--   AND (t.owner_user_id = 2 OR EXISTS (
--       SELECT 1 FROM theme_shares AS s
--       WHERE s.theme_id = t.id AND s.shared_with_user_id = 2
--   ))
-- ORDER BY v.address;

-- Revoke the share; only the owner (user 1) should be allowed:
-- DELETE s FROM theme_shares AS s
-- JOIN themes AS t ON t.id = s.theme_id
-- WHERE s.theme_id = 1
--   AND s.shared_with_user_id = 2
--   AND t.owner_user_id = 1;

-- Permissions enforced by the backend:
--   - Owner: manage theme details, verses, sharing, and deletion.
--   - Editor: read theme and add/edit/delete its verses, not manage sharing.
--   - Viewer: read only.
--   - Only grant access to themes owned by or shared with current user.
--   - Use authenticated user IDs (not caller-supplied IDs), SQL parameters,
--     and authorization checks for every read/write endpoint.
--   - The chosen utf8mb4_0900_ai_ci collation makes text uniqueness
--     case-insensitive AND accent-insensitive (e.g., Faith/faith are the same).
--   - Configure database session time zones consistently (prefer UTC) so
--     DATETIME values are written consistently across clients.
