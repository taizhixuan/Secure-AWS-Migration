<?php
require_once __DIR__ . '/../src/bootstrap.php';
require_once __DIR__ . '/../src/layout.php';
require_login();

$id      = (int) ($_GET['id'] ?? 0);
$editing = $id > 0;
$student = ['student_id' => '', 'name' => '', 'email' => '', 'program' => '', 'year' => 1];

if ($editing) {
    $stmt = db()->prepare('SELECT * FROM students WHERE id = ?');
    $stmt->execute([$id]);
    $student = $stmt->fetch() ?: $student;
}

$errors = [];
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    csrf_check();
    $student = [
        'student_id' => trim((string) ($_POST['student_id'] ?? '')),
        'name'       => trim((string) ($_POST['name'] ?? '')),
        'email'      => trim((string) ($_POST['email'] ?? '')),
        'program'    => trim((string) ($_POST['program'] ?? '')),
        'year'       => (int) ($_POST['year'] ?? 1),
    ];

    if ($student['student_id'] === '') {
        $errors[] = 'Student ID is required.';
    }
    if ($student['name'] === '') {
        $errors[] = 'Name is required.';
    }
    if ($student['email'] !== '' && !filter_var($student['email'], FILTER_VALIDATE_EMAIL)) {
        $errors[] = 'Email address is not valid.';
    }
    if ($student['year'] < 1 || $student['year'] > 7) {
        $errors[] = 'Year of study must be between 1 and 7.';
    }

    if (!$errors) {
        if ($editing) {
            $stmt = db()->prepare(
                'UPDATE students SET student_id = ?, name = ?, email = ?, program = ?, year = ? WHERE id = ?'
            );
            $stmt->execute([
                $student['student_id'], $student['name'], $student['email'],
                $student['program'], $student['year'], $id,
            ]);
            flash('Student updated.');
        } else {
            $stmt = db()->prepare(
                'INSERT INTO students (student_id, name, email, program, year) VALUES (?, ?, ?, ?, ?)'
            );
            $stmt->execute([
                $student['student_id'], $student['name'], $student['email'],
                $student['program'], $student['year'],
            ]);
            flash('Student added.');
        }
        redirect('students.php');
    }
}

render_header($editing ? 'Edit student' : 'Add student');
?>
<div class="card" style="max-width:640px">
  <?php foreach ($errors as $e): ?><div class="error"><?= icon('alert') ?><span><?= h($e) ?></span></div><?php endforeach; ?>
  <form method="post">
    <?= csrf_field() ?>
    <label>Student ID</label>
    <input name="student_id" value="<?= h($student['student_id']) ?>" placeholder="e.g. 1211109038" required>
    <label>Full name</label>
    <input name="name" value="<?= h($student['name']) ?>" placeholder="e.g. Tai Zhi Xuan" required>
    <label>Email</label>
    <input name="email" type="email" value="<?= h($student['email']) ?>" placeholder="name@student.mmu.edu.my">
    <label>Programme</label>
    <input name="program" value="<?= h($student['program']) ?>" placeholder="e.g. BACHELOR OF COMPUTER SCIENCE (HONOURS) (SOFTWARE ENGINEERING)">
    <label>Year of study</label>
    <input type="number" name="year" min="1" max="7" value="<?= h((string) $student['year']) ?>">
    <p class="row" style="margin-top:22px">
      <button class="btn primary" type="submit"><?= icon('check') ?> <?= $editing ? 'Save changes' : 'Add student' ?></button>
      <a class="btn alt" href="students.php">Cancel</a>
    </p>
  </form>
</div>
<?php render_footer();
