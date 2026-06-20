-- MMU Student Information System — database schema
-- Target: MySQL 8.0 (Amazon RDS for MySQL, Multi-AZ)

CREATE DATABASE IF NOT EXISTS sis CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE sis;

-- Application users (administrators of the SIS).
CREATE TABLE IF NOT EXISTS users (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(50)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Student records.
CREATE TABLE IF NOT EXISTS students (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    student_id VARCHAR(20)  NOT NULL UNIQUE,
    name       VARCHAR(100) NOT NULL,
    email      VARCHAR(120) DEFAULT NULL,
    program    VARCHAR(100) DEFAULT NULL,
    year       TINYINT      NOT NULL DEFAULT 1,
    created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_students_name (name),
    INDEX idx_students_program (program)
);

-- Seed administrator.
-- Default password: Admin@12345  ->  CHANGE THIS AFTER FIRST LOGIN.
-- Hash produced with PHP password_hash('Admin@12345', PASSWORD_BCRYPT).
INSERT INTO users (username, password_hash) VALUES
    ('admin', '$2y$10$EZZ/mK68itdhakF0phSqFOwMhDpt6AVsz8m2Vc4K8LiyW60HtEVyu')
ON DUPLICATE KEY UPDATE username = username;

-- Seed sample students.
INSERT INTO students (student_id, name, email, program, year) VALUES
    ('1211109038', 'Tai Zhi Xuan',   'taizhixuan@student.mmu.edu.my', 'BACHELOR OF COMPUTER SCIENCE (HONOURS) (SOFTWARE ENGINEERING)',     3),
    ('1231303310', 'Wong Hui Yee',   'wonghuiyee@student.mmu.edu.my', 'BACHELOR OF COMPUTER SCIENCE (HONOURS) (DATA SCIENCE)',            2),
    ('1211108625', 'Say Si Ting',    'saysiting@student.mmu.edu.my',  'BACHELOR OF INFORMATION TECHNOLOGY (HONOURS) (SECURITY TECHNOLOGY)', 3),
    ('1191100001', 'Ahmad bin Ali',  'ahmad@student.mmu.edu.my',      'BACHELOR OF SOFTWARE ENGINEERING (HONOURS)',                       4),
    ('1201100002', 'Siti Nurhaliza', 'siti@student.mmu.edu.my',       'BACHELOR OF COMPUTER SCIENCE (HONOURS) (ARTIFICIAL INTELLIGENCE)',  1)
ON DUPLICATE KEY UPDATE name = VALUES(name), email = VALUES(email), program = VALUES(program), year = VALUES(year);
