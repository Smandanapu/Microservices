provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "mcp_demo_vpc" {
  cidr_block = "172.10.127.0/24"
  instance_tenancy = "default"

  tags = {
    Name = "mcp-demo-vpc"
  }
}

resource "aws_subnet" "mcp_demo_subnet_1" {
  vpc_id     = aws_vpc.mcp_demo_vpc.id
  cidr_block = "172.10.127.0/25"
  availability_zone = "us-east-1a"

  tags = {
    Name = "mcp-demo-subnet-1"
  }
}

resource "aws_subnet" "mcp_demo_subnet_2" {
  vpc_id     = aws_vpc.mcp_demo_vpc.id
  cidr_block = "172.10.127.128/25"
  availability_zone = "us-east-1b"

  tags = {
    Name = "mcp-demo-subnet-2"
  }
}

resource "aws_subnet" "mcp_demo_subnet_3" {
  vpc_id     = aws_vpc.mcp_demo_vpc.id
  cidr_block = "172.10.128.0/25"
  availability_zone = "us-east-1c"

  tags = {
    Name = "mcp-demo-subnet-3"
  }
}
