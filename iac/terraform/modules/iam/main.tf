/*
 * IAM module: two distinct least-privilege roles for the ECS task.
 *
 *  - execution role : used by the ECS agent to pull the image, write logs and
 *                     fetch the database secret for injection. (Control plane.)
 *  - task role      : assumed by the application code itself; only the specific
 *                     S3 + KMS permissions the app needs. (Data plane.)
 *
 * No long-lived IAM users or access keys are created anywhere.
 */

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ----------------------------------------------------------- Execution role ----

resource "aws_iam_role" "execution" {
  name               = "${var.name_prefix}-ecs-exec"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = { Name = "${var.name_prefix}-ecs-exec" }
}

# AWS-managed policy: ECR pull + CloudWatch Logs write (standard for Fargate).
resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "exec_secrets" {
  statement {
    sid       = "ReadDbSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.db_secret_arn]
  }
  statement {
    sid       = "DecryptSecret"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "exec_secrets" {
  name   = "read-db-secret"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.exec_secrets.json
}

# ---------------------------------------------------------------- Task role ----

resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = { Name = "${var.name_prefix}-ecs-task" }
}

data "aws_iam_policy_document" "task_app" {
  statement {
    sid       = "AppDataObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.app_data_bucket_arn}/*"]
  }
  statement {
    sid       = "AppDataList"
    actions   = ["s3:ListBucket"]
    resources = [var.app_data_bucket_arn]
  }
  statement {
    sid       = "UseKmsForBucket"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.kms_key_arn]
  }
  # ECS Exec (debug via SSM Session Manager instead of SSH/bastion).
  statement {
    sid = "SSMExec"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task_app" {
  name   = "app-permissions"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_app.json
}
