# Secure Migration of a Traditional Application to AWS

> Secure re-platforming of a legacy LAMP monolith into a defense-in-depth AWS cloud architecture, implemented with Terraform (Infrastructure as Code), a containerized PHP application, a DevSecOps pipeline, and basic security validation.

## 1. Overview

A legacy **Student Information System** runs as a monolithic LAMP application (Apache + PHP + a locally installed
MySQL database) on a single on-premises server. This project assesses that legacy system's security weaknesses and
migrates it to a secure, highly-available AWS architecture:

- **Containerized PHP app** on **Amazon ECS Fargate** (no servers to patch)
- **Application Load Balancer** with **AWS WAF** (HTTPS + L7 filtering)
- **Amazon RDS for MySQL (Multi-AZ)** with encryption at rest
- A **2-AZ, dual-stack VPC** with public/private subnet tiers, Security Groups + NACLs
- **KMS** encryption everywhere, **Secrets Manager** for credentials, **CloudTrail/CloudWatch** for audit & monitoring
- Everything defined as modular **Terraform**

## 2. Repository layout

| Path | Contents |
|---|---|
| `app/` | PHP Student Information System + `Dockerfile` + database schema |
| `iac/terraform/` | Modular Terraform for the whole AWS architecture |
| `security-testing/` | Port-scan, WAF-bypass and encryption-verification scripts (Part E) |
| `.github/workflows/` | DevSecOps CI pipeline (lint, IaC scan, image scan) |

## 3. Prerequisites & installation

Tools needed to run and/or deploy this project.

| Tool | Why it's needed | Required? |
|:--|:--|:--:|
| **Git** | Clone the repo and push to GitHub | ✅ Required |
| **Docker Desktop** | Build & push the app image; run the app locally | ✅ Required |
| **AWS account + AWS CLI v2** | Create resources, log in to ECR, run ECS Exec | ✅ for AWS |
| **Terraform ≥ 1.5** | Provision all AWS infrastructure | ✅ for AWS |
| **Session Manager plugin** | Load the DB schema via ECS Exec | ✅ for AWS |
| **nmap** | Port-scan test (Part E) | ⬜ Optional* |

\* The PowerShell port-scan script falls back to `Test-NetConnection` if nmap is absent.

### 3.1 Install on Windows 11 (winget)

`winget` ships with Windows 11. Open **PowerShell** and run:

```powershell
winget install -e --id Git.Git
winget install -e --id Amazon.AWSCLI
winget install -e --id Docker.DockerDesktop
winget install -e --id Hashicorp.Terraform
winget install -e --id Amazon.SessionManagerPlugin
winget install -e --id Insecure.Nmap            # optional (Part E)
winget install -e --id JohnMacFarlane.Pandoc     # optional (rebuild report)
winget install -e --id Python.Python.3.12        # optional (rebuild report)
```

**Close and reopen your terminal** after installing so the new `PATH` entries load. Then **launch Docker Desktop
once** and wait until it says *"Engine running"* (it must be running before any `docker` command).

> If a `winget` ID is not found, download the official installer instead:
> [Git](https://git-scm.com/download/win) ·
> [AWS CLI](https://aws.amazon.com/cli/) ·
> [Docker Desktop](https://www.docker.com/products/docker-desktop/) ·
> [Terraform](https://developer.hashicorp.com/terraform/install) ·
> [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) ·
> [nmap](https://nmap.org/download.html) · [pandoc](https://pandoc.org/installing.html) ·
> [Python](https://www.python.org/downloads/)

### 3.2 Verify everything is installed

```bash
git --version && docker version && terraform version && aws --version && session-manager-plugin --version
```

### 3.3 Set up your AWS account

1. Sign in to the [AWS Console](https://console.aws.amazon.com/). For a coursework deploy, use an IAM user (or IAM
   Identity Center user) with broad permissions — **avoid using the root user** for daily work.
2. Create an **access key**: IAM → Users → your user → *Security credentials* → *Create access key* →
   *Command Line Interface (CLI)*.
3. Configure the CLI:

```bash
aws configure
#   AWS Access Key ID:     <your key>
#   AWS Secret Access Key: <your secret>
#   Default region name:   ap-southeast-1
#   Default output format: json
```

4. Verify it works:

```bash
aws sts get-caller-identity
```

> **Security:** never commit access keys to git (the `.gitignore` already blocks `*.pem`/`.env`). Delete the access
> key in the IAM console once you have finished the assignment.

## 4. Run locally (Docker Compose)

The fastest way to see the application — only Docker is required:

```bash
cd app
docker compose up --build
# open http://localhost:8080   (default login: admin / Admin@12345)
```

This starts the PHP app + a seeded MySQL database. Stop it with `docker compose down`.

## 5. Deploy to AWS — deployment & evidence-capture runbook

Step-by-step guide to deploy the secure SIS to AWS and capture the screenshots referenced in the report
(Figures 2–9). Commands assume `bash`; PowerShell equivalents are noted where they differ.

> **Cost & cleanup:** this stack uses Multi-AZ RDS, a NAT gateway, an ALB and Fargate — roughly **US$2–4/day** if
> left running. **Run `terraform destroy` when finished** (Step 5.7). Consider `db_multi_az=false` and
> `app_desired_count=1` while developing to reduce cost. (On a restricted AWS Free Tier account, set
> `db_multi_az=false` and `backup_retention_days=1`, since Multi-AZ and multi-day backups are blocked.)

### 5.1 Configure & initialise Terraform

```bash
cd iac/terraform
cp terraform.tfvars.example terraform.tfvars
#   (optional) edit terraform.tfvars: set admin_cidr to "<your-ip>/32", alarm_email, enable_ipv6, etc.
terraform init
```

### 5.2 Provision the infrastructure

```bash
terraform apply        # review the plan, type "yes"
```

This creates the VPC, subnets, NAT, KMS, Security Groups, WAF, RDS, Secrets Manager, IAM roles, ECR,
ECS cluster/service, ALB (with a self-signed HTTPS certificate), CloudTrail and CloudWatch.

> The ECS service is created before any image exists, so its tasks stay **PENDING** until Step 5.3. This is expected.

### 5.3 Build & push the application image

```bash
ECR=$(terraform output -raw ecr_repository_url)
REGION=$(aws configure get region)
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${ECR%/*}"
docker build -t "$ECR:latest" ../../app
docker push "$ECR:latest"

# Roll the service onto the image:
aws ecs update-service \
  --cluster "$(terraform output -raw ecs_cluster_name)" \
  --service "$(terraform output -raw ecs_service_name)" \
  --force-new-deployment
```

Wait until the service shows running tasks (Console: **ECS → Clusters → service → Tasks**, or
`aws ecs describe-services ...`). ⮕ **Figure 2.**

### 5.4 Load the database schema (secure, in-VPC)

The RDS instance is private. Load the schema with the bundled `migrate.php` via **ECS Exec** — no bastion, no SSH,
no public endpoint:

```bash
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)
TASK=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" --query 'taskArns[0]' --output text)

aws ecs execute-command --cluster "$CLUSTER" --task "$TASK" \
  --container app --interactive --command "php /var/www/app/db/migrate.php"
# Expected: "Migration complete: N statements executed."
```

**Alternative (no Session Manager plugin needed)** — run a one-off task:

```bash
aws ecs run-task --cluster "$CLUSTER" \
  --task-definition mmu-sis-prod-app --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$(terraform output -json app_subnet_ids | tr -d '[]\" ')],securityGroups=[$(terraform output -raw app_security_group_id)],assignPublicIp=DISABLED}" \
  --overrides '{"containerOverrides":[{"name":"app","command":["php","/var/www/app/db/migrate.php"]}]}'
```

### 5.5 Open the application

```bash
terraform output application_url      # e.g. https://mmu-sis-prod-alb-xxxx.ap-southeast-1.elb.amazonaws.com
```

Open it in a browser. The self-signed certificate triggers a one-time browser warning (expected) — proceed. Log in
with `admin` / `Admin@12345` and **change the password**. ⮕ **Figure 6** (browser padlock / certificate).

### 5.6 Run the security validation (Part E)

```bash
ALB=$(terraform output -raw alb_dns_name)
../../security-testing/port-scan.sh "$ALB"                 # only 80,443 open
../../security-testing/waf-test.sh "https://$ALB"          # attacks -> 403
AWS_REGION=ap-southeast-1 ../../security-testing/verify-encryption.sh mmu-sis-prod
```

### 5.7 Tear down (avoid ongoing charges)

```bash
terraform destroy      # type "yes"
```

> **Region:** the stack deploys to `ap-southeast-1` (Singapore) by default — set the AWS Console region accordingly.
