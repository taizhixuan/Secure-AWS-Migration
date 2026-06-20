<?php
declare(strict_types=1);

/*
 * Small view/security helpers shared across pages.
 */

/** Escape output to prevent reflected/stored XSS. Always use when echoing data. */
function h(?string $value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES | ENT_HTML5, 'UTF-8');
}

/* ---- CSRF protection ---- */

function csrf_token(): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf'];
}

function csrf_field(): string
{
    return '<input type="hidden" name="csrf" value="' . h(csrf_token()) . '">';
}

function csrf_check(): void
{
    $sent = $_POST['csrf'] ?? '';
    if (!is_string($sent) || !hash_equals($_SESSION['csrf'] ?? '', $sent)) {
        http_response_code(400);
        exit('Invalid CSRF token.');
    }
}

/* ---- Flash messages + redirect ---- */

function flash(string $msg): void
{
    $_SESSION['flash'] = $msg;
}

function take_flash(): ?string
{
    $m = $_SESSION['flash'] ?? null;
    unset($_SESSION['flash']);
    return $m;
}

function redirect(string $path): void
{
    header('Location: ' . $path);
    exit;
}
