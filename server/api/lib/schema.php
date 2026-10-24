<?php
// Tabelle del database. Stesso schema per MySQL/MariaDB (Hostinger) e SQLite (test in locale).
declare(strict_types=1);

function schema_statements(bool $sqlite): array
{
    $engine = $sqlite ? '' : ' ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci';
    $id = 'CHAR(36) NOT NULL PRIMARY KEY';
    $text = $sqlite ? 'TEXT' : 'TEXT';
    $bool = $sqlite ? 'INTEGER' : 'TINYINT(1)';
    $dt = $sqlite ? 'TEXT' : 'DATETIME';

    return [
        "CREATE TABLE IF NOT EXISTS users (
            id $id,
            email VARCHAR(190) NOT NULL UNIQUE,
            password_hash VARCHAR(255) NOT NULL,
            is_admin $bool NOT NULL DEFAULT 0,
            created_at $dt NOT NULL
        )$engine",

        "CREATE TABLE IF NOT EXISTS auth_tokens (
            token_hash CHAR(64) NOT NULL PRIMARY KEY,
            user_id CHAR(36) NOT NULL,
            expires_at $dt NOT NULL,
            created_at $dt NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )$engine",

        "CREATE TABLE IF NOT EXISTS login_attempts (
            ip VARCHAR(64) NOT NULL,
            attempted_at $dt NOT NULL
        )$engine",

        "CREATE TABLE IF NOT EXISTS yards (
            id $id,
            owner_id CHAR(36) NOT NULL,
            name VARCHAR(80) NOT NULL,
            city VARCHAR(80) NOT NULL DEFAULT '',
            province VARCHAR(2) NOT NULL DEFAULT '',
            address VARCHAR(160) NOT NULL DEFAULT '',
            phone VARCHAR(40) NOT NULL DEFAULT '',
            whatsapp VARCHAR(40) NOT NULL DEFAULT '',
            email VARCHAR(190) NOT NULL DEFAULT '',
            hours VARCHAR(160) NOT NULL DEFAULT '',
            description $text,
            lat DOUBLE NULL,
            lng DOUBLE NULL,
            published $bool NOT NULL DEFAULT 1,
            created_at $dt NOT NULL,
            FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
        )$engine",

        "CREATE TABLE IF NOT EXISTS yard_members (
            yard_id CHAR(36) NOT NULL,
            user_id CHAR(36) NOT NULL,
            role VARCHAR(10) NOT NULL DEFAULT 'staff',
            PRIMARY KEY (yard_id, user_id),
            FOREIGN KEY (yard_id) REFERENCES yards(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )$engine",

        "CREATE TABLE IF NOT EXISTS vehicles (
            id $id,
            yard_id CHAR(36) NOT NULL,
            make VARCHAR(40) NOT NULL,
            model VARCHAR(60) NOT NULL,
            version VARCHAR(80) NOT NULL DEFAULT '',
            year INT NULL,
            fuel VARCHAR(12) NOT NULL DEFAULT '',
            color VARCHAR(40) NOT NULL DEFAULT '',
            km INT NULL,
            engine_code VARCHAR(30) NOT NULL DEFAULT '',
            damage_zones VARCHAR(255) NOT NULL DEFAULT '',
            notes $text,
            status VARCHAR(12) NOT NULL DEFAULT 'available',
            published $bool NOT NULL DEFAULT 1,
            arrived_on DATE NOT NULL,
            created_at $dt NOT NULL,
            updated_at $dt NOT NULL,
            FOREIGN KEY (yard_id) REFERENCES yards(id) ON DELETE CASCADE
        )$engine",

        "CREATE INDEX " . ($sqlite ? 'IF NOT EXISTS ' : '') . "vehicles_yard_idx ON vehicles (yard_id)",
        "CREATE INDEX " . ($sqlite ? 'IF NOT EXISTS ' : '') . "vehicles_search_idx ON vehicles (make, model, year)",

        "CREATE TABLE IF NOT EXISTS vehicle_photos (
            id $id,
            vehicle_id CHAR(36) NOT NULL,
            file VARCHAR(120) NOT NULL,
            position INT NOT NULL DEFAULT 0,
            created_at $dt NOT NULL,
            FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE
        )$engine",
    ];
}

function create_schema(PDO $pdo, bool $sqlite): void
{
    foreach (schema_statements($sqlite) as $sql) {
        try {
            $pdo->exec($sql);
        } catch (PDOException $e) {
            // MySQL non ha CREATE INDEX IF NOT EXISTS: un indice già presente va bene
            if (!str_contains($e->getMessage(), 'Duplicate key name')) {
                throw $e;
            }
        }
    }
}
