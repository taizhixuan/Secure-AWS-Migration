<?php
require_once __DIR__ . '/../src/bootstrap.php';
require_once __DIR__ . '/../src/layout.php';
require_login();

// Delete (POST + CSRF only).
if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'delete') {
    csrf_check();
    $stmt = db()->prepare('DELETE FROM students WHERE id = ?');
    $stmt->execute([(int) ($_POST['id'] ?? 0)]);
    flash('Student deleted.');
    redirect('students.php');
}

$rows = db()->query('SELECT id, student_id, name, email, program, year FROM students ORDER BY name')->fetchAll();

render_header('Students');
?>
<div class="card-head">
  <h2>All students <span class="muted">(<?= count($rows) ?>)</span></h2>
  <a class="btn primary" href="student_form.php"><?= icon('plus') ?> Add student</a>
</div>
<div class="table-wrap">
  <table>
    <thead><tr><th>Student ID</th><th>Name</th><th>Email</th><th>Programme</th><th>Year</th><th style="text-align:right">Actions</th></tr></thead>
    <tbody>
      <?php foreach ($rows as $s): ?>
      <tr>
        <td class="id-cell"><?= h($s['student_id']) ?></td>
        <td><?= h($s['name']) ?></td>
        <td class="muted"><?= h($s['email']) ?></td>
        <td><?= h($s['program']) ?></td>
        <td><span class="badge year">Year <?= h((string) $s['year']) ?></span></td>
        <td>
          <div class="row" style="justify-content:flex-end;gap:8px;flex-wrap:nowrap">
            <a class="btn alt sm" href="student_form.php?id=<?= (int) $s['id'] ?>">Edit</a>
            <form method="post" onsubmit="return confirm('Delete this student?')">
              <?= csrf_field() ?>
              <input type="hidden" name="action" value="delete">
              <input type="hidden" name="id" value="<?= (int) $s['id'] ?>">
              <button class="btn danger sm" type="submit">Delete</button>
            </form>
          </div>
        </td>
      </tr>
      <?php endforeach; ?>
      <?php if (!$rows): ?><tr><td colspan="6" class="empty">No students yet &mdash; click &ldquo;Add student&rdquo; to begin.</td></tr><?php endif; ?>
    </tbody>
  </table>
</div>
<?php render_footer();
