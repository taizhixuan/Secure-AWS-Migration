<?php
/*
 * One-off database migration / seeding. Run INSIDE the container, e.g. via
 * ECS Exec (no public endpoint, no bastion, no SSH):
 *
 *   aws ecs execute-command --cluster <cluster> --task <task-id> \
 *     --container app --interactive --command "php /var/www/app/db/migrate.php"
 *
 * It uses the same Secrets-Manager-injected credentials as the app and is
 * idempotent (CREATE TABLE IF NOT EXISTS + INSERT ... ON DUPLICATE KEY).
 */
declare(strict_types=1);

require __DIR__ . '/../src/db.php';

$pdo = db();
$sql = file_get_contents(__DIR__ . '/schema.sql');

// The app already connects to the target database, so skip CREATE DATABASE/USE.
$statements = array_filter(
    array_map('trim', explode(';', $sql)),
    static function (string $s): bool {
        if ($s === '') {
            return false;
        }
        $u = strtoupper($s);
        return !str_starts_with($u, 'CREATE DATABASE') && !str_starts_with($u, 'USE ');
    }
);

$count = 0;
foreach ($statements as $stmt) {
    $pdo->exec($stmt);
    $count++;
}

echo "Migration complete: {$count} statements executed.\n";
