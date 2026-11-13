variable "region" {
  type        = string
  description = "Région autorisée par AWS Academy"
  default     = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "devsecops-eks"
}

# ---- Phase 9 : Wazuh ----
variable "enable_wazuh_lab" {
  type        = bool
  description = "Crée le serveur Wazuh si true"
  default     = false
}

variable "my_ip" {
  type        = string
  description = "Ton IP publique au format x.x.x.x/32"
  default     = "127.0.0.1/32"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Chemin de la clé publique SSH pour le serveur Wazuh"
  default     = "~/.ssh/id_ed25519.pub"
}
