# Three subnet tiers, mirroring the three application tiers:
#   public   -> load balancers and NAT gateway (route to the internet gateway)
#   private  -> EKS worker nodes (outbound only, through NAT)
#   database -> RDS (NO route to the internet at all, in either direction)

locals {
  az_count = length(var.azs)

  # Carve /24 subnets out of the /16: 10.0.0.x, 10.0.1.x (public), 10.0.10.x, 10.0.11.x (private), 10.0.20.x, 10.0.21.x (database)
  public_cidrs   = [for i in range(local.az_count) : cidrsubnet(var.cidr, 8, i)]
  private_cidrs  = [for i in range(local.az_count) : cidrsubnet(var.cidr, 8, i + 10)]
  database_cidrs = [for i in range(local.az_count) : cidrsubnet(var.cidr, 8, i + 20)]

  nat_count = var.single_nat_gateway ? 1 : local.az_count
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true # EKS and RDS endpoints need DNS resolution
  enable_dns_hostnames = true

  tags = { Name = "${var.name}-vpc" }
}

# ---------- Internet access ----------

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

resource "aws_subnet" "public" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false # nothing should get a public IP by accident; the ALB gets its own

  tags = {
    Name                                        = "${var.name}-public-${var.azs[count.index]}"
    Tier                                        = "public"
    "kubernetes.io/role/elb"                    = "1" # internet-facing load balancers land here
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "private" {
  count             = local.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name                                        = "${var.name}-private-${var.azs[count.index]}"
    Tier                                        = "private"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "database" {
  count             = local.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.database_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.name}-database-${var.azs[count.index]}"
    Tier = "database"
  }
}

# ---------- NAT (lets private nodes pull images and talk to AWS APIs) ----------

resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"
  tags   = { Name = "${var.name}-nat-eip-${count.index}" }
}

resource "aws_nat_gateway" "this" {
  count         = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id # NAT lives in a PUBLIC subnet

  tags       = { Name = "${var.name}-nat-${count.index}" }
  depends_on = [aws_internet_gateway.this]
}

# ---------- Route tables ----------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-public-rt" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = local.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = local.az_count
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-private-rt-${var.azs[count.index]}" }
}

resource "aws_route" "private_nat" {
  count                  = local.az_count
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  # With a single NAT every AZ routes to NAT #0; otherwise each AZ uses its own.
  nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
}

resource "aws_route_table_association" "private" {
  count          = local.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Database subnets get a route table with NO default route. Local VPC traffic only.
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-database-rt" }
}

resource "aws_route_table_association" "database" {
  count          = local.az_count
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

# ---------- Lock down the default security group ----------
# The VPC's default SG allows all traffic between its members. Strip every rule so nothing uses it by accident.

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-default-sg-locked" }
}

# ---------- VPC flow logs (network audit trail) ----------

resource "aws_cloudwatch_log_group" "flow" {
  name              = "/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_log_retention_days
}

data "aws_iam_policy_document" "flow_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow" {
  name               = "${var.name}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_assume.json
}

data "aws_iam_policy_document" "flow_write" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = ["${aws_cloudwatch_log_group.flow.arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow" {
  name   = "write-flow-logs"
  role   = aws_iam_role.flow.id
  policy = data.aws_iam_policy_document.flow_write.json
}

resource "aws_flow_log" "this" {
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow.arn
  iam_role_arn         = aws_iam_role.flow.arn
}
