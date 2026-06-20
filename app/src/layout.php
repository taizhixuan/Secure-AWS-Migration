<?php
declare(strict_types=1);

/*
 * HTML layout. Two shells, chosen automatically:
 *   - logged in  -> sidebar "app" dashboard shell
 *   - logged out -> centered "auth" shell (login page)
 */

require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/auth.php';

/** Inline Feather-style icons (18px, currentColor). */
function icon(string $name): string
{
    $p = [
        'grid'   => '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/>',
        'users'  => '<path d="M17 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9.5" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
        'search' => '<circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/>',
        'plus'   => '<circle cx="12" cy="12" r="9"/><path d="M12 8v8M8 12h8"/>',
        'logout' => '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="m16 17 5-5-5-5"/><path d="M21 12H9"/>',
        'check'  => '<path d="M20 6 9 17l-5-5"/>',
        'alert'  => '<circle cx="12" cy="12" r="9"/><path d="M12 8v4M12 16h.01"/>',
    ][$name] ?? '';
    return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' . $p . '</svg>';
}

function nav_link(string $href, string $label, string $iconName, string $current): void
{
    $active = ($current === $href) ? ' active' : '';
    echo '<a href="' . $href . '" class="nav-link' . $active . '">' . icon($iconName) . '<span>' . h($label) . '</span></a>';
}

function render_header(string $title): void
{
    $user    = current_user();
    $current = basename($_SERVER['SCRIPT_NAME'] ?? 'index.php');
    ?><!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= h($title) ?> &middot; MMU SIS</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,400;9..144,500;9..144,600;9..144,700&family=Outfit:wght@300;400;500;600;700&display=swap">
<link rel="stylesheet" href="/assets/style.css">
</head>
<?php if (!$user): ?>
<body class="auth"><div class="auth-card">
<?php return; endif; ?>
<body class="app">
<aside class="sidebar">
  <div class="brand">
    <div class="brand-mark">M</div>
    <div class="brand-text"><strong>MMU SIS</strong><span>Student Records</span></div>
  </div>
  <div class="nav-section">Menu</div>
  <nav class="nav">
    <?php
    nav_link('index.php', 'Dashboard', 'grid', $current);
    nav_link('students.php', 'Students', 'users', $current);
    nav_link('search.php', 'Search', 'search', $current);
    nav_link('student_form.php', 'Add student', 'plus', $current);
    ?>
  </nav>
  <div class="sidebar-foot">
    <div class="user">
      <div class="avatar"><?= h(strtoupper(substr($user['username'], 0, 1))) ?></div>
      <div><div class="uname"><?= h($user['username']) ?></div><div class="urole">Administrator</div></div>
    </div>
    <a class="logout" href="logout.php" title="Log out"><?= icon('logout') ?></a>
  </div>
</aside>
<main class="main">
  <header class="topbar">
    <div><div class="crumb">MMU Student Information System</div><h1 class="page-title"><?= h($title) ?></h1></div>
  </header>
  <div class="content">
<?php $f = take_flash(); if ($f): ?><div class="flash"><?= icon('check') ?><span><?= h($f) ?></span></div><?php endif; ?>
<?php
}

function render_footer(): void
{
    if (current_user() === null) {
        echo "</div></body></html>";
        return;
    }
    ?>
  </div>
</main>
</body>
</html>
<?php
}
