<?php
declare(strict_types=1);

/*
 * Central configuration.
 *
 * Every sensitive value is read from an environment variable. In AWS these are
 * injected into the ECS Fargate task at runtime from AWS Secrets Manager, so
 * NO credentials are ever hard-coded in the source or baked into the image.
 */

if (!function_exists('env')) {
    function env(string $key, ?string $default = null): ?string
    {
        $val = getenv($key);
        return ($val === false || $val === '') ? $default : $val;
    }
}

return [
    'db' => [
        'host'   => env('DB_HOST', 'localhost'),
        'port'   => (int) env('DB_PORT', '3306'),
        'name'   => env('DB_NAME', 'sis'),
        'user'   => env('DB_USER', 'sis_app'),
        'pass'   => env('DB_PASS', ''),
        // Path to the Amazon RDS CA bundle. When set, TLS is enforced on the
        // database connection (encryption in transit to RDS).
        'ssl_ca' => env('DB_SSL_CA'),
    ],
    'app' => [
        'env'  => env('APP_ENV', 'production'),
        'name' => 'MMU Student Information System',
    ],
];
