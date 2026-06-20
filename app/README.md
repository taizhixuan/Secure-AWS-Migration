# Student Information System (PHP) — Application

A small, deliberately simple PHP + MySQL **Student Information System** representing the legacy LAMP workload that is
migrated to AWS. It is written to be **secure by default** so it can be deployed safely on ECS Fargate + RDS.

## Structure

```
app/
├── public/         # web document root (only these files are reachable over HTTP)
│   ├── index.php           # dashboard
│   ├── login.php / logout.php
│   ├── students.php        # list + delete
│   ├── student_form.php    # add / edit
│   ├── search.php          # search (parameterized; WAF demo surface)
│   └── health.php          # ALB health-check endpoint (no DB dependency)
├── src/            # application library — OUTSIDE the web root, not HTTP-accessible
│   ├── bootstrap.php       # hardened session + autoload
│   ├── config.php          # reads all config from environment variables
│   ├── db.php              # PDO connection (prepared statements, optional RDS TLS)
│   ├── auth.php            # bcrypt login, session-fixation protection
│   ├── helpers.php         # output escaping, CSRF, flash
│   └── layout.php          # HTML layout
├── db/schema.sql   # tables + seed data
└── Dockerfile      # php:8.2-apache, hardened
```

## Run locally (Docker Compose)

```bash
cd app
docker compose up --build
# open http://localhost:8080
```

**Default administrator:** `admin` / `Admin@12345` — change it immediately after first login.

## Configuration (environment variables)

| Variable | Purpose | Source in AWS |
|---|---|---|
| `DB_HOST`, `DB_PORT`, `DB_NAME` | database connection target | task definition env / Secrets Manager |
| `DB_USER`, `DB_PASS` | database credentials | **AWS Secrets Manager** (injected at runtime) |
| `DB_SSL_CA` | path to RDS CA bundle; enables TLS to RDS when set | mounted/baked CA bundle |
| `APP_ENV` | `production` / `local` | task definition env |

No secret is ever stored in source or baked into the image.

## Apply the schema to Amazon RDS

```bash
mysql -h <rds-endpoint> -u <admin-user> -p --ssl-ca=global-bundle.pem < db/schema.sql
```

## Security features built in

- **SQL injection:** every query uses PDO **prepared statements** (`ATTR_EMULATE_PREPARES=false`).
- **XSS:** all output escaped via `h()`.
- **CSRF:** token on every state-changing form.
- **Sessions:** `HttpOnly` + `SameSite=Strict` + `Secure` (over HTTPS), id regenerated on login.
- **Passwords:** bcrypt (`password_hash` / `password_verify`).
- **Headers:** `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`; PHP/Apache version banners disabled.
- **Isolation:** application library lives outside the web document root.
