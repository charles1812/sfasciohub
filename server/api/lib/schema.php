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

        ai_usage_table_sql($sqlite),

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

/** Una riga per ogni analisi delle foto con l'AI (limite giornaliero e costi). */
function ai_usage_table_sql(bool $sqlite): string
{
    $engine = $sqlite ? '' : ' ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci';
    $dt = $sqlite ? 'TEXT' : 'DATETIME';
    return "CREATE TABLE IF NOT EXISTS ai_usage (
            yard_id CHAR(36) NOT NULL,
            user_id CHAR(36) NOT NULL,
            used_at $dt NOT NULL,
            input_tokens INTEGER NOT NULL DEFAULT 0,
            output_tokens INTEGER NOT NULL DEFAULT 0
        )$engine";
}

const SCHEMA_VERSION = 4;

/**
 * Modifiche allo schema per i server già installati. Ogni versione gira una volta sola
 * (il numero raggiunto resta in api/schema.flag); colonne e indici già presenti si ignorano.
 */
function migrate_schema(PDO $pdo, bool $sqlite): void
{
    $flag = __DIR__ . '/../schema.flag';
    $version = is_file($flag) ? (int) file_get_contents($flag) : (is_file(__DIR__ . '/../schema_v2.flag') ? 2 : 1);
    if ($version >= SCHEMA_VERSION) {
        return;
    }
    $bool = $sqlite ? 'INTEGER' : 'TINYINT(1)';
    $engine = $sqlite ? '' : ' ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci';
    $dt = $sqlite ? 'TEXT' : 'DATETIME';
    $steps = [
        2 => [
            ai_usage_table_sql($sqlite),
            "ALTER TABLE users ADD COLUMN disabled $bool NOT NULL DEFAULT 0",
            'ALTER TABLE yards ADD COLUMN ai_daily_limit INT NULL',
        ],
        3 => [
            "ALTER TABLE ai_usage ADD COLUMN kind VARCHAR(12) NOT NULL DEFAULT 'photos'",
            "CREATE TABLE IF NOT EXISTS vehicle_parts (
                vehicle_id CHAR(36) NOT NULL,
                part_id VARCHAR(40) NOT NULL,
                name VARCHAR(120) NOT NULL,
                zone VARCHAR(12) NOT NULL,
                status VARCHAR(8) NOT NULL,
                confirmed $bool NOT NULL DEFAULT 0,
                note VARCHAR(200) NOT NULL DEFAULT '',
                updated_at $dt NOT NULL,
                PRIMARY KEY (vehicle_id, part_id),
                FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE
            )$engine",
            'CREATE INDEX ' . ($sqlite ? 'IF NOT EXISTS ' : '') . 'vehicle_parts_part_idx ON vehicle_parts (part_id, status)',
        ],
        4 => [
            'ALTER TABLE ai_usage ADD COLUMN images INT NOT NULL DEFAULT 0',
            'ALTER TABLE ai_usage ADD COLUMN duration_ms INT NOT NULL DEFAULT 0',
            "ALTER TABLE ai_usage ADD COLUMN status VARCHAR(10) NOT NULL DEFAULT 'ok'",
            "ALTER TABLE ai_usage ADD COLUMN error VARCHAR(200) NOT NULL DEFAULT ''",
            'ALTER TABLE ai_usage ADD COLUMN vehicle_id CHAR(36) NULL',
            'CREATE INDEX ' . ($sqlite ? 'IF NOT EXISTS ' : '') . 'ai_usage_time_idx ON ai_usage (used_at)',
        ],
    ];
    foreach ($steps as $v => $sqls) {
        if ($v <= $version) {
            continue;
        }
        foreach ($sqls as $sql) {
            try {
                $pdo->exec($sql);
            } catch (PDOException $e) {
                if (!preg_match('/duplicate (column|key name)/i', $e->getMessage())) {
                    throw $e;
                }
            }
        }
    }
    @file_put_contents($flag, SCHEMA_VERSION . "\n");
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
