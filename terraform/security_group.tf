# ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group ───
# ─── Source : https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html ───
resource "aws_security_group" "web_sg" {
  name        = "web-devsecops-sg"
  description = "Web server security group - least privilege egress"
  vpc_id      = aws_vpc.main.id

  # SSH : admin uniquement
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
    description = "SSH from trusted IP"
  }

  # HTTP : public (justifié - serveur web)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP public access"
  }

  # EGRESS RESTREINT - correction DevSecOps
  # HTTPS : mises à jour, packages, Git
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for updates and packages"
  }

  # DNS : résolution de noms
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS TCP resolution"
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS UDP resolution"
  }

  tags = {
    Name = "sg-web"
  }
}
