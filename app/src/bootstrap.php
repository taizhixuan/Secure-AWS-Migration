<?php
declare(strict_types=1);

/*
 * Request bootstrap. Included first by every public page.
 *
 * Starts a hardened session and loads the shared libraries. Behind the AWS
 * Application Load Balancer, TLS terminates at the ALB and traffic is forwarded
 * to the container, so HTTPS is detected via the X-Forwarded-Proto header.
 */

$isHttps = (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https')
        || (($_SERVER['HTTPS'] ?? '') === 'on');

session_set_cookie_params([
    'lifetime' => 0,
    'path'     => '/',
    'httponly' => true,      // not readable by JavaScript
    'secure'   => $isHttps,  // only sent over HTTPS
    'samesite' => 'Strict',  // CSRF hardening
]);
session_start();

require_once __DIR__ . '/db.php';
require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/auth.php';
