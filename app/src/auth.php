<?php
declare(strict_types=1);

/*
 * Authentication.
 *
 * Passwords are stored as bcrypt hashes (password_hash) and verified with
 * password_verify. Login lookups use prepared statements. On success the
 * session id is regenerated to prevent session fixation.
 */

require_once __DIR__ . '/db.php';
require_once __DIR__ . '/helpers.php';

function current_user(): ?array
{
    return $_SESSION['user'] ?? null;
}

function require_login(): void
{
    if (current_user() === null) {
        redirect('login.php');
    }
}

function attempt_login(string $username, string $password): bool
{
    $stmt = db()->prepare('SELECT id, username, password_hash FROM users WHERE username = ? LIMIT 1');
    $stmt->execute([$username]);
    $user = $stmt->fetch();

    if ($user && password_verify($password, $user['password_hash'])) {
        session_regenerate_id(true); // prevent session fixation
        $_SESSION['user'] = ['id' => (int) $user['id'], 'username' => $user['username']];
        return true;
    }
    return false;
}

function logout(): void
{
    $_SESSION = [];
    session_destroy();
}
