# Terraform — Secure AWS Infrastructure

Modular Terraform that provisions the full secure architecture for the migrated Student Information System.

## Modules

| Module | Responsibility |
|---|---|
| `network` | VPC, 3 subnet tiers (public / app / **isolated** data), IGW, NAT, route tables, NACLs, optional IPv6 |
| `security` | KMS CMK (rotation on), the `ALB → App → DB` Security-Group chain, AWS WAF Web ACL |
| `storage` | S3 buckets (ALB logs = SSE-S3; app data = SSE-KMS) — versioned, TLS-only, public access blocked |
| `database` | RDS MySQL Multi-AZ (encrypted) + generated credentials in Secrets Manager |
| `iam` | Least-privilege ECS **execution** + **task** roles (no IAM users/keys) |
| `compute` | ECR, ECS Fargate cluster/service/task, ALB, HTTP→HTTPS redirect, self-signed ACM cert, WAF association, encrypted log group |
| `observability` | CloudTrail (multi-region, validated, KMS) → S3 + CloudWatch, security alarms, Inspector (optional) |

## Prerequisites

- Terraform >= 1.5, AWS CLI configured (`aws configure`) with an account that can create these resources.
- Docker (to build and push the application image).

## Deploy 

```bash
cp terraform.tfvars.example terraform.tfvars      # edit as needed
terraform init
terraform apply                                   # creates everything incl. an empty ECR repo

# Build & push the image to the repo Terraform just created:
ECR=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin "${ECR%/*}"
docker build -t "$ECR:latest" ../../app
docker push "$ECR:latest"

# Roll the service onto the new image:
aws ecs update-service --cluster $(terraform output -raw ecs_cluster_name) \
  --service $(terraform output -raw ecs_service_name) --force-new-deployment

terraform output application_url
```

> **First apply:** the ECS service starts before the image exists, so tasks stay *PENDING* until you push the
> image and force a new deployment. This is expected.

## Key security properties

- Encryption at rest (RDS, S3, Secrets, logs via **KMS**) and in transit (**HTTPS/TLS** on the ALB).
- DB credentials only in **Secrets Manager**, injected at runtime — never in code or the image.
- Tasks run in **private** subnets; the data tier has **no internet route** at all.
- Least-privilege Security Groups (SG references, not CIDRs) + subnet NACLs.
- **WAF** managed rules (Common + SQLi + Known-Bad-Inputs) + rate limiting.
- **CloudTrail** multi-region with log-file validation; security alarms for unauthorized API / root usage.

## Teardown

```bash
terraform destroy
```

Buckets use `force_destroy = true` and the DB uses `skip_final_snapshot = true` so coursework teardown is clean.
Set `db_deletion_protection = true` and `force_destroy = false` for production.
