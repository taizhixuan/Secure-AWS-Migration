/*
 * Security module: KMS customer-managed key, the three-tier Security Group
 * chain (ALB -> App -> DB), and the AWS WAF Web ACL.
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ------------------------------------------------------------------- KMS ----
# One customer-managed key (with annual rotation) encrypts RDS, S3, Secrets
# Manager and CloudWatch Logs.
resource "aws_kms_key" "main" {
  description             = "${var.name_prefix} CMK (RDS / S3 / Secrets / Logs)"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccount"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${data.aws_region.current.name}.amazonaws.com" }
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource  = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      },
      {
        Sid       = "AllowAWSServices"
        Effect    = "Allow"
        Principal = { Service = ["cloudtrail.amazonaws.com", "rds.amazonaws.com", "s3.amazonaws.com", "secretsmanager.amazonaws.com"] }
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:CreateGrant", "kms:DescribeKey"]
        Resource  = "*"
      }
    ]
  })

  tags = { Name = "${var.name_prefix}-cmk" }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.name_prefix}"
  target_key_id = aws_kms_key.main.key_id
}

# -------------------------------------------------------- Security Groups ----

# ALB: public-facing.
resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb-"
  description = "ALB - allow HTTP/HTTPS from clients"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name_prefix}-alb-sg" }
  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP (redirected to HTTPS)"
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS"
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_v6" {
  count             = var.enable_ipv6 ? 1 : 0
  security_group_id = aws_security_group.alb.id
  description       = "HTTP IPv6"
  cidr_ipv6         = "::/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "alb_https_v6" {
  count             = var.enable_ipv6 ? 1 : 0
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS IPv6"
  cidr_ipv6         = "::/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "alb_egress" {
  security_group_id = aws_security_group.alb.id
  description       = "All outbound (to app tasks)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# App tier: only reachable from the ALB.
resource "aws_security_group" "app" {
  name_prefix = "${var.name_prefix}-app-"
  description = "App tasks - allow app port from ALB only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name_prefix}-app-sg" }
  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "App port from ALB security group"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
}

resource "aws_vpc_security_group_egress_rule" "app_egress" {
  security_group_id = aws_security_group.app.id
  description       = "All outbound (RDS, ECR, Secrets, logs)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Data tier: only reachable from the app tier on MySQL.
resource "aws_security_group" "db" {
  name_prefix = "${var.name_prefix}-db-"
  description = "RDS - allow MySQL from app tier only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name_prefix}-db-sg" }
  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL from app security group"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
}

resource "aws_vpc_security_group_egress_rule" "db_egress" {
  security_group_id = aws_security_group.db.id
  description       = "Responses within VPC"
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "-1"
}

# ------------------------------------------------------------------- WAF ----
# Regional Web ACL associated with the ALB (association lives in the compute
# module, which owns the ALB ARN).
resource "aws_wafv2_web_acl" "this" {
  name        = "${var.name_prefix}-waf"
  description = "WAF for the SIS ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedCommon"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedSQLi"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-sqli"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedKnownBadInputs"
    priority = 3
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-badinputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimitPerIP"
    priority = 4
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-ratelimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = { Name = "${var.name_prefix}-waf" }
}
