<?php
require_once __DIR__ . '/../src/bootstrap.php';
require_once __DIR__ . '/../src/layout.php';
require_login();

$total    = (int) db()->query('SELECT COUNT(*) FROM students')->fetchColumn();
$programs = (int) db()->query('SELECT COUNT(DISTINCT program) FROM students WHERE program IS NOT NULL')->fetchColumn();
$recent   = db()->query('SELECT student_id, name, program, year FROM students ORDER BY id DESC LIMIT 5')->fetchAll();

render_header('Dashboard');
?>
<div class="stats">
  <div class="stat">
    <div class="ic"><?= icon('users') ?></div>
    <div class="label">Total students</div>
    <div class="value"><?= $total ?></div>
  </div>
  <div class="stat">
    <div class="ic"><?= icon('grid') ?></div>
    <div class="label">Programmes</div>
    <div class="value"><?= $programs ?></div>
  </div>
  <div class="stat">
    <div class="ic"><?= icon('plus') ?></div>
    <div class="label">Quick action</div>
    <div style="margin-top:14px"><a class="btn primary sm" href="student_form.php"><?= icon('plus') ?> Add student</a></div>
  </div>
</div>

<div class="card-head">
  <h2>Recently added</h2>
  <a class="btn alt" href="students.php">View all &rarr;</a>
</div>
<div class="table-wrap">
  <table>
    <thead><tr><th>Student ID</th><th>Name</th><th>Programme</th><th>Year</th></tr></thead>
    <tbody>
      <?php foreach ($recent as $s): ?>
      <tr>
        <td class="id-cell"><?= h($s['student_id']) ?></td>
        <td><?= h($s['name']) ?></td>
        <td><?= h($s['program']) ?></td>
        <td><span class="badge year">Year <?= h((string) $s['year']) ?></span></td>
      </tr>
      <?php endforeach; ?>
      <?php if (!$recent): ?><tr><td colspan="4" class="empty">No students yet &mdash; add your first one.</td></tr><?php endif; ?>
    </tbody>
  </table>
</div>
<?php render_footer();
