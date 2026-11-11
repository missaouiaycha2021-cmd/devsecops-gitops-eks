###############################################################################
# Données existantes (lues, non créées)
###############################################################################
# AWS Academy interdit de créer des rôles IAM : on réutilise LabRole
data "aws_iam_role" "lab" {
  name = "LabRole"
}

# Zones de disponibilité de la région
data "aws_availability_zones" "available" {
  state = "available"
}

# On garde 2 zones
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

###############################################################################
# Réseau
###############################################################################
# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.cluster_name}-vpc" }
}

# 2 sous-réseaux publics (ELB, NAT)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index) # 10.0.0.0/24, 10.0.1.0/24
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.cluster_name}-public-${count.index}"
    "kubernetes.io/role/elb" = "1"
  }
}

# 2 sous-réseaux privés (nœuds EKS)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 10) # 10.0.10.0/24, 10.0.11.0/24
  availability_zone = local.azs[count.index]

  tags = {
    Name                              = "${var.cluster_name}-private-${count.index}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.cluster_name}-igw" }
}

# Elastic IP de la NAT
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.cluster_name}-nat-eip" }
}

# NAT Gateway (placée dans un sous-réseau public)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.cluster_name}-nat" }

  depends_on = [aws_internet_gateway.main]
}

# Table de routage publique : sortie vers l'Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.cluster_name}-public-rt" }
}

# Table de routage privée : sortie vers la NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "${var.cluster_name}-private-rt" }
}

# Associations tables ↔ sous-réseaux public
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
# Associations tables ↔ sous-réseaux privé
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

###############################################################################
# EKS
###############################################################################
# Cluster (control plane)
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = data.aws_iam_role.lab.arn

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  depends_on = [aws_route_table_association.private]
}

# Groupe de nœuds : 2 x t3.medium
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = data.aws_iam_role.lab.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 2
  }

  depends_on = [aws_route_table_association.private]
}

# Add-ons
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
  depends_on   = [aws_eks_node_group.main]
}

###############################################################################
# Phase 9 : Wazuh + cible (créés seulement si enable_wazuh_lab = true)
###############################################################################
# Image Ubuntu 22.04
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Clé SSH
resource "aws_key_pair" "lab" {
  count      = var.enable_wazuh_lab ? 1 : 0
  key_name   = "${var.cluster_name}-lab-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# Security Group de la cible : SSH depuis ton IP
resource "aws_security_group" "target" {
  count       = var.enable_wazuh_lab ? 1 : 0
  name        = "${var.cluster_name}-target-sg"
  description = "SSH depuis mon IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group de Wazuh : 443 et 22 depuis ton IP, 1514/1515 depuis la cible
resource "aws_security_group" "wazuh" {
  count       = var.enable_wazuh_lab ? 1 : 0
  name        = "${var.cluster_name}-wazuh-sg"
  description = "Wazuh server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Dashboard HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description     = "Agent events"
    from_port       = 1514
    to_port         = 1514
    protocol        = "tcp"
    security_groups = [aws_security_group.target[0].id]
  }

  ingress {
    description     = "Agent enrollment"
    from_port       = 1515
    to_port         = 1515
    protocol        = "tcp"
    security_groups = [aws_security_group.target[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Wazuh (le disque EBS racine est inclus)
resource "aws_instance" "wazuh" {
  count                  = var.enable_wazuh_lab ? 1 : 0
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.xlarge"
  subnet_id              = aws_subnet.public[0].id
  key_name               = aws_key_pair.lab[0].key_name
  vpc_security_group_ids = [aws_security_group.wazuh[0].id]

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = "${var.cluster_name}-wazuh" }
}

# EC2 cible contient wazuh agent
resource "aws_instance" "target" {
  count                       = var.enable_wazuh_lab ? 1 : 0
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[1].id
  key_name                    = aws_key_pair.lab[0].key_name
  vpc_security_group_ids      = [aws_security_group.target[0].id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = "${var.cluster_name}-target" }
}

# IP publique fixe pour le dashboard Wazuh
resource "aws_eip" "wazuh" {
  count    = var.enable_wazuh_lab ? 1 : 0
  instance = aws_instance.wazuh[0].id
  domain   = "vpc"
}