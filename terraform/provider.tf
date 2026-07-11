# ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs#argument-reference ───
# ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs#default_tags-configuration-block ───
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "DevSecOps-L3"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}
