/*
 * Network module.
 *
 * Builds a multi-AZ, dual-stack-capable VPC with three subnet tiers:
 *   - public  : internet-facing (ALB, NAT gateway)
 *   - app     : private, outbound via NAT (ECS Fargate tasks)
 *   - data    : private and ISOLATED (no internet route) for RDS
 *
 * Stateful Security Groups (security module) do the fine-grained control;
 * stateless NACLs here add a second, subnet-level layer (defense-in-depth).
 */

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

resource "aws_vpc" "this" {
  cidr_block                       = var.vpc_cidr
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = var.enable_ipv6

  tags = { Name = "${var.name_prefix}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-igw" }
}

# IPv6 outbound-only gateway for private subnets (bonus).
resource "aws_egress_only_internet_gateway" "this" {
  count  = var.enable_ipv6 ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-eigw" }
}

# ---------------------------------------------------------------- Subnets ----

resource "aws_subnet" "public" {
  count                           = var.az_count
  vpc_id                          = aws_vpc.this.id
  availability_zone               = local.azs[count.index]
  cidr_block                      = cidrsubnet(var.vpc_cidr, 8, count.index)
  map_public_ip_on_launch         = false
  ipv6_cidr_block                 = var.enable_ipv6 ? cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, count.index) : null
  assign_ipv6_address_on_creation = var.enable_ipv6

  tags = { Name = "${var.name_prefix}-public-${count.index + 1}", Tier = "public" }
}

resource "aws_subnet" "app" {
  count                           = var.az_count
  vpc_id                          = aws_vpc.this.id
  availability_zone               = local.azs[count.index]
  cidr_block                      = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  ipv6_cidr_block                 = var.enable_ipv6 ? cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, count.index + 10) : null
  assign_ipv6_address_on_creation = var.enable_ipv6

  tags = { Name = "${var.name_prefix}-app-${count.index + 1}", Tier = "app" }
}

resource "aws_subnet" "data" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)

  tags = { Name = "${var.name_prefix}-data-${count.index + 1}", Tier = "data" }
}

# ------------------------------------------------------------------- NAT ----

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.name_prefix}-nat-eip" }
}

# Single NAT gateway (cost-optimized). For production HA, deploy one per AZ.
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.name_prefix}-nat" }
  depends_on    = [aws_internet_gateway.this]
}

# --------------------------------------------------------- Route tables ----

# Public: route to the internet gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-rt-public" }
}

resource "aws_route" "public_ipv4" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route" "public_ipv6" {
  count                       = var.enable_ipv6 ? 1 : 0
  route_table_id              = aws_route_table.public.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# App: outbound via NAT (IPv4) and egress-only IGW (IPv6).
resource "aws_route_table" "app" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-rt-app" }
}

resource "aws_route" "app_ipv4" {
  route_table_id         = aws_route_table.app.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route" "app_ipv6" {
  count                       = var.enable_ipv6 ? 1 : 0
  route_table_id              = aws_route_table.app.id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.this[0].id
}

resource "aws_route_table_association" "app" {
  count          = var.az_count
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app.id
}

# Data: no internet route at all (isolated). Local VPC routing only.
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-rt-data" }
}

resource "aws_route_table_association" "data" {
  count          = var.az_count
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

# ------------------------------------------------------------------ NACLs ----
# Stateless, so return traffic needs explicit ephemeral-port rules.
# IPv6 ingress (when enabled) is governed by the stateful Security Groups.

resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.public[*].id
  tags       = { Name = "${var.name_prefix}-nacl-public" }

  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = 80
    to_port    = 80
    cidr_block = "0.0.0.0/0"
  }
  ingress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    from_port  = 443
    to_port    = 443
    cidr_block = "0.0.0.0/0"
  }
  ingress {
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
  }
}

resource "aws_network_acl" "app" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.app[*].id
  tags       = { Name = "${var.name_prefix}-nacl-app" }

  # Inbound from the load balancer (within the VPC) to the app port.
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = var.app_port
    to_port    = var.app_port
    cidr_block = var.vpc_cidr
  }
  # Return traffic for the tasks' own outbound calls (ECR, Secrets, logs via NAT).
  ingress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
  }
}

resource "aws_network_acl" "data" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.data[*].id
  tags       = { Name = "${var.name_prefix}-nacl-data" }

  # Only MySQL from inside the VPC; no internet exposure.
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = 3306
    to_port    = 3306
    cidr_block = var.vpc_cidr
  }
  ingress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = var.vpc_cidr
  }
  # Responses stay inside the VPC (also covers Multi-AZ replication).
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = var.vpc_cidr
  }
}
