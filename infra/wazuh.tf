###############################################################################
# Phase 9 : Wazuh (créé seulement si enable_wazuh_lab = true)
# L'EC2 "cible" est supprimée : les agents tournent sur les nœuds EKS.
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

# Security Group de Wazuh : 443 et 22 depuis ton IP, 1514/1515 depuis les nœuds EKS
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

  # Les nœuds du groupe managé utilisent le security group du cluster EKS
  ingress {
    description     = "Agent events (nœuds EKS)"
    from_port       = 1514
    to_port         = 1514
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description     = "Agent enrollment (nœuds EKS)"
    from_port       = 1515
    to_port         = 1515
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
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

# IP publique fixe pour le dashboard Wazuh
resource "aws_eip" "wazuh" {
  count    = var.enable_wazuh_lab ? 1 : 0
  instance = aws_instance.wazuh[0].id
  domain   = "vpc"
}
