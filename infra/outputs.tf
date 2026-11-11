output "vpc_id" {
  value = aws_vpc.main.id
}

output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "wazuh_public_ip" {
  value = one(aws_eip.wazuh[*].public_ip)
}

output "wazuh_private_ip" {
  value = one(aws_instance.wazuh[*].private_ip)
}

output "target_public_ip" {
  value = one(aws_instance.target[*].public_ip)
}