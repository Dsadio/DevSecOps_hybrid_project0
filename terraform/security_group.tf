resource "aws_security_group" "web_sg" {
  name        = "web-devsecops-sg"
  description = "Web server security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
    description = "SSH from trusted IP"
  }

  # Serveur web public : exposition HTTP volontaire et assumée (cf. mémoire §5.1.2).
  #tfsec:ignore:aws-ec2-no-public-ingress-sgr
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP public access (documented trade-off)"
  }

  # Egress ouvert : simplification pédagogique assumée (cf. mémoire §5.1.2).
  # Une restriction fine du trafic sortant relève d'une maturité DevSecOps ultérieure.
  #tfsec:ignore:aws-ec2-no-public-egress-sgr
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Outbound traffic (unrestricted, documented trade-off)"
  }
}
