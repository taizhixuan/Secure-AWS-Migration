/*
 * Observability & audit module.
 *  - CloudTrail: multi-region, log-file validation, KMS-encrypted, delivered to
 *    a locked-down S3 bucket AND CloudWatch Logs.
 *  - Security alarms: unauthorized-API and root-account-usage metric filters
 *    with CloudWatch alarms -> SNS.
 *  - Amazon Inspector enhanced ECR scanning (optional, bonus).
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  trail_name = "${var.name_prefix}-trail"
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  trail_arn  = "arn:aws:cloudtrail:${local.region}:${local.account_id}:trail/${local.trail_name}"
}

# --------------------------------------------------- CloudTrail S3 bucket ----

resource "aws_s3_bucket" "trail" {
  bucket        = "${var.name_prefix}-cloudtrail-${local.account_id}"
  force_destroy = var.force_destroy
  tags          = { Name = "${var.name_prefix}-cloudtrail" }
}

resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "trail" {
  bucket = aws_s3_bucket.trail.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "trail" {
  bucket = aws_s3_bucket.trail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.trail.arn
        Condition = { StringEquals = { "aws:SourceArn" = local.trail_arn } }
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.trail.arn}/AWSLogs/${local.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "aws:SourceArn" = local.trail_arn
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.trail.arn, "${aws_s3_bucket.trail.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }
    ]
  })
}

# ------------------------------------------- CloudTrail -> CloudWatch Logs ----

resource "aws_cloudwatch_log_group" "trail" {
  name              = "/aws/cloudtrail/${var.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = { Name = "${var.name_prefix}-trail-logs" }
}

resource "aws_iam_role" "trail_cw" {
  name = "${var.name_prefix}-cloudtrail-cw"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "trail_cw" {
  name = "deliver-to-cloudwatch"
  role = aws_iam_role.trail_cw.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.trail.arn}:*"
    }]
  })
}

# ------------------------------------------------------------ CloudTrail ----

resource "aws_cloudtrail" "this" {
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.trail.id
  kms_key_id                    = var.kms_key_arn
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.trail_cw.arn

  tags = { Name = local.trail_name }

  depends_on = [aws_s3_bucket_policy.trail]
}

# ----------------------------------------------------- Security alarms ----

resource "aws_sns_topic" "alarms" {
  name = "${var.name_prefix}-security-alarms"
  tags = { Name = "${var.name_prefix}-security-alarms" }
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_log_metric_filter" "unauthorized" {
  name           = "${var.name_prefix}-unauthorized-api"
  log_group_name = aws_cloudwatch_log_group.trail.name
  pattern        = "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }"

  metric_transformation {
    name      = "UnauthorizedApiCalls"
    namespace = "${var.name_prefix}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized" {
  alarm_name          = "${var.name_prefix}-unauthorized-api"
  alarm_description   = "Unauthorized or access-denied API calls detected"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedApiCalls"
  namespace           = "${var.name_prefix}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_log_metric_filter" "root_usage" {
  name           = "${var.name_prefix}-root-usage"
  log_group_name = aws_cloudwatch_log_group.trail.name
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"

  metric_transformation {
    name      = "RootAccountUsage"
    namespace = "${var.name_prefix}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "root_usage" {
  alarm_name          = "${var.name_prefix}-root-account-usage"
  alarm_description   = "Root account was used"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsage"
  namespace           = "${var.name_prefix}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"
}

# ------------------------------------ Amazon Inspector (bonus, optional) ----

resource "aws_inspector2_enabler" "this" {
  count          = var.enable_inspector ? 1 : 0
  account_ids    = [local.account_id]
  resource_types = ["ECR"]
}

resource "aws_ecr_registry_scanning_configuration" "this" {
  count     = var.enable_inspector ? 1 : 0
  scan_type = "ENHANCED"
  rule {
    scan_frequency = "SCAN_ON_PUSH"
    repository_filter {
      filter      = "*"
      filter_type = "WILDCARD"
    }
  }
  depends_on = [aws_inspector2_enabler.this]
}
