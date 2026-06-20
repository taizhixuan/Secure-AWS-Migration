<?php
require_once __DIR__ . '/../src/bootstrap.php';
require_once __DIR__ . '/../src/layout.php';

if (current_user()) {
    redirect('index.php');
}

$error = null;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    csrf_check();
    $username = trim((string) ($_POST['username'] ?? ''));
    $password = (string) ($_POST['password'] ?? '');

    if (attempt_login($username, $password)) {
        flash('Welcome back, ' . $username . '!');
        redirect('index.php');
    }
    $error = 'Invalid username or password.';
}

render_header('Sign in'); // opens the auth shell (.auth-card)
?>
<div class="auth-brand">
  <div class="brand-mark">M</div>
  <div class="brand-text"><strong>MMU SIS</strong><span>Student Information System</span></div>
</div>
<h2>Welcome back</h2>
<p class="sub">Sign in to manage student records.</p>
<?php if ($error): ?><div class="error"><?= icon('alert') ?><span><?= h($error) ?></span></div><?php endif; ?>
<form method="post">
  <?= csrf_field() ?>
  <label>Username</label>
  <input name="username" autocomplete="username" autofocus required>
  <label>Password</label>
  <input type="password" name="password" autocomplete="current-password" required>
  <button class="btn primary" type="submit">Sign in &rarr;</button>
</form>
<p class="muted" style="margin-top:18px">Default administrator is documented in <code>app/README.md</code> &mdash; change it after first login.</p>
<?php render_footer();
