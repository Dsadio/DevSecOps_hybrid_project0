# ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc ───
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-devsecops"
  }
}

# ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet ───
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-public"
  }
}

# ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway ───
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-devsecops"
  }
}

# ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table ───
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "rt-public"
  }
}

# ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association ───
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
