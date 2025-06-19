terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "aws_region" {
  description = "The AWS region to create resources in."
  type        = string
  default     = "us-west-2"
}

provider "aws" {
  region = var.aws_region
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr_blocks" {
  description = "List of CIDR blocks for the subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.eks_cluster_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.subnet_cidr_blocks)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr_blocks[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true // Important for public subnets

  tags = {
    Name                                = "${var.eks_cluster_name}-public-subnet-${count.index + 1}"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared" // Required for EKS
    "kubernetes.io/role/elb"            = "1"                 // Required for public load balancers
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.eks_cluster_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.eks_cluster_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name               = "${var.eks_cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

data "aws_iam_policy_document" "eks_node_group_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node_group_role" {
  name               = "${var.eks_cluster_name}-node-group-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_group_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

variable "eks_cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
  default     = "mcp-demo-cluster"
}

variable "eks_cluster_version" {
  description = "The Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.29" # Specify a recent, valid version
}

resource "aws_eks_cluster" "main" {
  name     = var.eks_cluster_name
  version  = var.eks_cluster_version
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = aws_subnet.public[*].id
    # endpoint_private_access = false # Default: false
    # endpoint_public_access  = true  # Default: true
    # public_access_cidrs     = ["0.0.0.0/0"] # Default
  }

  # Ensure EKS Cluster an IAM Role for EKS to manage the cluster are created
  # Ensure VPC and subnets are created and specified in vpc_config
  depends_on = [
    aws_iam_role.eks_cluster_role,
    aws_vpc.main,
    aws_subnet.public,
    aws_internet_gateway.main
  ]
}

resource "aws_eks_node_group" "blue_nodes" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "blue-nodegroup-${aws_eks_cluster.main.version}"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = aws_subnet.public[*].id

  instance_types = ["t3.medium"] # Example instance type
  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  # Ensure the EKS cluster is created before the node group
  # Ensure an IAM role for the node group is created
  depends_on = [
    aws_eks_cluster.main,
    aws_iam_role.eks_node_group_role
  ]

  tags = {
    Name        = "blue-nodegroup-${aws_eks_cluster.main.version}"
    Environment = "dev"
    Color       = "blue"
  }
}

resource "aws_eks_node_group" "green_nodes" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "green-nodegroup-${aws_eks_cluster.main.version}"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = aws_subnet.public[*].id

  instance_types = ["t3.medium"] # Example instance type
  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  # Ensure the EKS cluster is created before the node group
  # Ensure an IAM role for the node group is created
  depends_on = [
    aws_eks_cluster.main,
    aws_iam_role.eks_node_group_role
  ]

  tags = {
    Name        = "green-nodegroup-${aws_eks_cluster.main.version}"
    Environment = "dev"
    Color       = "green"
  }
}

output "eks_cluster_name" {
  description = "The name of the EKS cluster."
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "The endpoint for your EKS Kubernetes API server."
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_arn" {
  description = "The ARN of the EKS cluster."
  value       = aws_eks_cluster.main.arn
}

output "eks_cluster_oidc_issuer_url" {
  description = "The OIDC issuer URL for the EKS cluster."
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "blue_node_group_arn" {
  description = "The ARN of the blue EKS managed node group."
  value       = aws_eks_node_group.blue_nodes.arn
}

output "green_node_group_arn" {
  description = "The ARN of the green EKS managed node group."
  value       = aws_eks_node_group.green_nodes.arn
}

output "vpc_id" {
  description = "The ID of the VPC created for the EKS cluster."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets."
  value       = aws_subnet.public[*].id
}
