/*
 * Compute module: ECR + ECS Fargate service behind an ALB with WAF and HTTPS.
 *
 * HTTPS works out of the box: if no ACM certificate ARN is supplied, a
 * self-signed certificate is generated and imported into ACM (zero cost, no
 * domain required). Browsers show a name-mismatch warning for the self-signed
 * certificate — that is expected; supply `certificate_arn` for a trusted cert.
 */

data "aws_region" "current" {}

locals {
  create_self_signed = var.certificate_arn == "" && var.enable_self_signed_cert
  # Decide HTTPS from INPUT variables only, so it is known at plan time
  # (values used in count/for_each cannot depend on not-yet-created resources).
  enable_https   = var.certificate_arn != "" || var.enable_self_signed_cert
  https_cert_arn = var.certificate_arn != "" ? var.certificate_arn : (local.create_self_signed ? aws_acm_certificate.selfsigned[0].arn : null)
  image          = var.app_image != "" ? var.app_image : "${aws_ecr_repository.this.repository_url}:latest"
}

# ------------------------------------------------------------------- ECR ----

resource "aws_ecr_repository" "this" {
  name                 = var.name_prefix
  image_tag_mutability = "MUTABLE" # IMMUTABLE recommended for production
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "${var.name_prefix}-ecr" }
}

# ---------------------------------------------------- Self-signed TLS cert ----

resource "tls_private_key" "selfsigned" {
  count     = local.create_self_signed ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "selfsigned" {
  count           = local.create_self_signed ? 1 : 0
  private_key_pem = tls_private_key.selfsigned[0].private_key_pem

  subject {
    common_name  = "${var.name_prefix}.example.com"
    organization = "MMU SIS"
  }

  validity_period_hours = 8760
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
  dns_names             = ["${var.name_prefix}.example.com"]
}

resource "aws_acm_certificate" "selfsigned" {
  count            = local.create_self_signed ? 1 : 0
  private_key      = tls_private_key.selfsigned[0].private_key_pem
  certificate_body = tls_self_signed_cert.selfsigned[0].cert_pem

  tags = { Name = "${var.name_prefix}-selfsigned" }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------- ALB ----

resource "aws_lb" "this" {
  name                       = "${var.name_prefix}-alb"
  load_balancer_type         = "application"
  security_groups            = [var.alb_sg_id]
  subnets                    = var.public_subnet_ids
  ip_address_type            = var.enable_ipv6 ? "dualstack" : "ipv4"
  drop_invalid_header_fields = true
  enable_deletion_protection = false

  access_logs {
    bucket  = var.alb_logs_bucket
    prefix  = "alb"
    enabled = true
  }

  tags = { Name = "${var.name_prefix}-alb" }
}

resource "aws_lb_target_group" "this" {
  name        = "${var.name_prefix}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health.php"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  # Pin each client to one task so PHP's local file-based sessions persist
  # across requests (the app tier runs multiple tasks for high availability).
  stickiness {
    type            = "lb_cookie"
    enabled         = true
    cookie_duration = 86400
  }

  tags = { Name = "${var.name_prefix}-tg" }
}

# HTTP listener: redirect to HTTPS when a certificate exists, otherwise forward.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = local.enable_https ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = local.enable_https ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this.arn
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = local.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.https_cert_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# Attach the WAF Web ACL to the ALB.
resource "aws_wafv2_web_acl_association" "this" {
  resource_arn = aws_lb.this.arn
  web_acl_arn  = var.waf_acl_arn
}

# ------------------------------------------------------------------- ECS ----

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${var.name_prefix}-cluster" }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = { Name = "${var.name_prefix}-logs" }
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.name_prefix}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = local.image
      essential = true
      portMappings = [
        { containerPort = var.app_port, protocol = "tcp" }
      ]
      environment = [
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_PORT", value = "3306" },
        { name = "APP_ENV", value = "production" }
      ]
      # Injected from Secrets Manager by the execution role (never in the image).
      secrets = [
        { name = "DB_HOST", valueFrom = "${var.db_secret_arn}:host::" },
        { name = "DB_USER", valueFrom = "${var.db_secret_arn}:username::" },
        { name = "DB_PASS", valueFrom = "${var.db_secret_arn}:password::" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  tags = { Name = "${var.name_prefix}-task" }
}

resource "aws_ecs_service" "this" {
  name             = "${var.name_prefix}-svc"
  cluster          = aws_ecs_cluster.this.id
  task_definition  = aws_ecs_task_definition.this.arn
  desired_count    = var.app_desired_count
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    subnets          = var.app_subnet_ids
    security_groups  = [var.app_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "app"
    container_port   = var.app_port
  }

  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  enable_execute_command             = true # debug via SSM Session Manager, no SSH

  depends_on = [aws_lb_listener.http]

  tags = { Name = "${var.name_prefix}-svc" }
}
