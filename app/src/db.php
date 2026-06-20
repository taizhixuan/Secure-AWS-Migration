<?php
declare(strict_types=1);

/*
 * Database access layer.
 *
 * Returns a singleton PDO connection configured for security:
 *  - real (non-emulated) server-side prepared statements
 *  - exceptions on error
 *  - optional TLS to Amazon RDS when a CA bundle is provided
 */

function db(): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $config = require __DIR__ . '/config.php';
    $db = $config['db'];

    $dsn = sprintf(
        'mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',
        $db['host'],
        $db['port'],
        $db['name']
    );

    $options = [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false, // true server-side prepared statements
    ];

    // Encryption in transit to RDS when a CA bundle path is supplied.
    if (!empty($db['ssl_ca'])) {
        $options[PDO::MYSQL_ATTR_SSL_CA] = $db['ssl_ca'];
        $options[PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT] = true;
    }

    $pdo = new PDO($dsn, $db['user'], $db['pass'], $options);
    return $pdo;
}
