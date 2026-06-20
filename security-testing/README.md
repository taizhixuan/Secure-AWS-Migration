# Part E — Security Validation

This folder contains the security-testing **scripts** and the **results captured from our live AWS deployment**
(region `ap-southeast-1`). The tests confirm that the migrated environment actually enforces the intended security
controls. Each test maps back to a legacy risk identified in Part A and to a figure in the report.

> **The verified outputs are shown inline below.** The commands are included so the tests are fully reproducible
> against a fresh deployment.

## Results summary

| # | Test | Tool | Result | Mitigates |
|:--|:--|:--|:--|:--|
| **T1** | Port scan of the public endpoint | `nmap` | ✅ **PASS** — only 80/443 open; 22 & 3306 filtered | R1 — network exposure |
| **T2** | WAF SQL-injection / XSS | `curl` | ✅ **PASS** — attacks blocked (HTTP 403); legitimate request 200 | R8 — application attacks |
| **T3** | Encryption at rest | AWS CLI | ✅ **PASS** — RDS, S3 & Secrets encrypted with KMS | R4 — data protection |
| **T4** | Audit logging | CloudTrail | ✅ **PASS** — multi-region trail + log-file validation | R6 — monitoring/detection |
| **T5** | Encryption in transit | `curl` | ✅ **PASS** — HTTPS served; HTTP → HTTPS (301) | R7 — data in transit |

## Scripts in this folder

| Script | What it does |
|:--|:--|
| `run-all.sh` / `run-all.ps1` | **Runs every test (T1–T5) in one command** |
| `port-scan.sh` / `port-scan.ps1` | Scans the public endpoint (nmap, or `Test-NetConnection` fallback on Windows) |
| `waf-test.sh` / `waf-test.ps1` | Sends SQL-injection / XSS payloads and reports the HTTP status |
| `verify-encryption.sh` | Confirms RDS / S3 / Secrets Manager / CloudTrail encryption via the AWS CLI |

## How to run

Prerequisites: a deployed stack (see the root `README.md`), the **AWS CLI configured**, and `nmap` (optional — the
Windows port-scan falls back to `Test-NetConnection`).

### Run ALL tests in one command (recommended)

From this `security-testing/` folder:

**Windows (PowerShell):**

```powershell
powershell -ExecutionPolicy Bypass -File .\run-all.ps1
```

**Linux / macOS:**

```bash
./run-all.sh
```

This runs T1–T5 in sequence and prints every result. If you redeployed and the ALB DNS changed, pass it explicitly:
`.\run-all.ps1 -Alb <alb-dns>` (PowerShell) or `./run-all.sh <alb-dns>` (bash).

### Or run tests individually

```bash
ALB=$(terraform -chdir=../iac/terraform output -raw alb_dns_name)
./port-scan.sh "$ALB"                                   # T1
./waf-test.sh "https://$ALB"                            # T2
AWS_REGION=ap-southeast-1 ./verify-encryption.sh mmu-sis-prod   # T3 + T4
```

Windows (PowerShell): `.\port-scan.ps1 -Target <alb>` and `.\waf-test.ps1 -BaseUrl https://<alb>`.

---

## T1 — Port scan (network exposure → risk R1)

**Goal:** prove that only the web ports are reachable from the internet and the database is never exposed.

```bash
nmap -Pn -p 22,80,443,3306 mmu-sis-prod-alb-1870207398.ap-southeast-1.elb.amazonaws.com
```

**Actual result:**

```
PORT     STATE    SERVICE
22/tcp   filtered ssh
80/tcp   open     http
443/tcp  open     https
3306/tcp filtered mysql
```

Only 80/443 are open. SSH and MySQL are **filtered** — the ALB security group only allows 80/443, and RDS sits in
private, isolated subnets with no route to the internet. *(Report Figure 7.)*

## T2 — WAF SQL-injection / XSS (application layer → risk R8)

**Goal:** prove AWS WAF blocks injection/XSS at the edge before requests reach the application.

**Actual result:**

```
GET /login.php  (legitimate)                         -> 200 OK
GET /search.php?q=' OR '1'='1                         -> 403 Forbidden (blocked)
GET /search.php?q=1 UNION SELECT username,password... -> 403 Forbidden (blocked)
GET /search.php?q=<script>alert(1)</script>           -> 403 Forbidden (blocked)
```

The managed rule groups (Common + SQLi + Known-Bad-Inputs) return **403** for the malicious requests while
legitimate traffic passes. Defense-in-depth: the application *also* uses PDO prepared statements, so it is not
injectable even if a request bypassed the WAF. *(Report Figure 8.)*

## T3 — Encryption at rest (data protection → risk R4)

**Goal:** prove all stored data is encrypted with a customer-managed KMS key.

**Actual result:**

```
RDS  mmu-sis-prod-mysql        StorageEncrypted = true   (KMS CMK 4fc935a0-…)
S3   mmu-sis-prod-app-data     SSE = aws:kms (CMK)
S3   mmu-sis-prod-cloudtrail   SSE = aws:kms (CMK)
S3   mmu-sis-prod-alb-logs     SSE = AES256 (SSE-S3)*
Secrets Manager db-credentials KmsKeyId = (CMK)
```

\* The ALB-logs bucket uses SSE-S3 because the ALB access-log delivery service does not support customer KMS keys;
all other stores use the customer-managed key. *(Report Figure 9.)*

## T4 — Audit logging (monitoring/detection → risk R6)

**Goal:** prove security-relevant activity is recorded in a tamper-evident way.

**Actual result:**

```
CloudTrail  mmu-sis-prod-trail   MultiRegion = true   LogFileValidation = true   KMS = enabled
```

The trail is multi-region with log-file validation, delivers to an encrypted S3 bucket and to CloudWatch Logs, and
CloudWatch alarms fire on unauthorized-API and root-account usage. Review events in **CloudTrail → Event history**.

## T5 — Encryption in transit (data in transit → risk R7)

The ALB serves the application over **HTTPS (TLS 1.2/1.3)** and redirects HTTP to HTTPS:

```
GET http://<alb>/   -> 301 Moved Permanently  (Location: https://<alb>/)
GET https://<alb>/  -> 200 OK
```

*(For the demo a self-signed certificate imported into ACM is used; a trusted ACM/Route 53 certificate would remove
the browser warning in production.)*

---

> **Authorisation note:** only scan and test endpoints **you own** (your own AWS deployment). Unauthorised scanning
> or attacking of third-party systems is illegal.
