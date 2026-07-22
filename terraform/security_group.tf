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

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP public access"
  }

  # Egress ouvert : simplification pédagogique assumée (cf. mémoire §5.1.2).
  # Une restriction fine du trafic sortant relève d'une maturité DevSecOps ultérieure.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Outbound traffic (unrestricted, documented trade-off)"
  }
}
