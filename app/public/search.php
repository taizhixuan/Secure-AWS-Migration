<?php
require_once __DIR__ . '/../src/bootstrap.php';
require_once __DIR__ . '/../src/layout.php';
require_login();

$q       = trim((string) ($_GET['q'] ?? ''));
$results = [];

if ($q !== '') {
    /*
     * SECURE BY DESIGN: parameterized LIKE search (positional placeholders, one
     * value bound per "?"). The application is not vulnerable to SQL injection;
     * AWS WAF blocks injection signatures at the edge as a second layer.
     */
    $like = '%' . $q . '%';
    $stmt = db()->prepare(
        'SELECT student_id, name, email, program, year FROM students
         WHERE student_id LIKE ? OR name LIKE ? OR program LIKE ?
         ORDER BY name LIMIT 50'
    );
    $stmt->execute([$like, $like, $like]);
    $results = $stmt->fetchAll();
}

render_header('Search');
?>
<div class="card">
  <form method="get" class="row">
    <input name="q" value="<?= h($q) ?>" placeholder="Search by student ID, name or programme&hellip;" style="flex:1;min-width:220px" autofocus>
    <button class="btn primary" type="submit"><?= icon('search') ?> Search</button>
  </form>
</div>

<?php if ($q !== ''): ?>
<div class="card-head">
  <h3>Results for &ldquo;<?= h($q) ?>&rdquo; <span class="muted">(<?= count($results) ?>)</span></h3>
</div>
<div class="table-wrap">
  <table>
    <thead><tr><th>Student ID</th><th>Name</th><th>Email</th><th>Programme</th><th>Year</th></tr></thead>
    <tbody>
      <?php foreach ($results as $s): ?>
      <tr>
        <td class="id-cell"><?= h($s['student_id']) ?></td>
        <td><?= h($s['name']) ?></td>
        <td class="muted"><?= h($s['email']) ?></td>
        <td><?= h($s['program']) ?></td>
        <td><span class="badge year">Year <?= h((string) $s['year']) ?></span></td>
      </tr>
      <?php endforeach; ?>
      <?php if (!$results): ?><tr><td colspan="5" class="empty">No matches found.</td></tr><?php endif; ?>
    </tbody>
  </table>
</div>
<?php endif; ?>
<?php render_footer();
