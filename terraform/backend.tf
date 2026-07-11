terraform {
  backend "s3" {
    bucket       = "tfstate-devsecops-l3-sadio"
    key          = "devsecops-hybrid/terraform.tfstate"
    region       = "eu-west-3"
    use_lockfile = true
    encrypt      = true
  }
}
