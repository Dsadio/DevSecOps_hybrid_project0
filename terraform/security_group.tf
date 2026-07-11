# ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group ───
# ─── Source : https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html ───
resource "aws_security_group" "web_sg" {
  name        = "web-devsecops-sg"
  description = "Web server security group"
  vpc_id      = aws_vpc.main.id

  # SSH : admin uniquement
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
    description = "SSH from trusted IP"
  }

  # HTTP : public
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP public access"
  }

  # Egress : tout autorisé (simplification pédagogique)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-web"
  }
}
