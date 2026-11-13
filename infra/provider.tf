provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "devsecops-gitops-eks"
      Managed = "terraform"
    }
  }
}
