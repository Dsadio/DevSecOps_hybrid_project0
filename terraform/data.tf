# ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami ───
# ─── Exemple : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami#example-usage ───
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    # ─── Source : https://cloud-images.ubuntu.com/locator/ec2/ ───
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}