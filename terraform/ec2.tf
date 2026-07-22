data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "web" {
  name = "web-devsecops-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "web_logs" {
  name = "web-devsecops-logs-put" 
  role = aws_iam_role.web.id

  policy = jsonencode({
    Version = "2012-10-17"  
    Statement = [{
      Sid      = "PutLogsOnly"
      Effect   = "Allow"
      Action   = "s3:PutObject"  
      Resource = "${aws_s3_bucket.logs.arn}/*"
    }]
  })
}

resource "aws_iam_instance_profile" "web" {
  name = "web-devsecops-profile"
  role = aws_iam_role.web.name  
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.web.name

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3" 
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y python3
              EOF

  tags = {
    Name = "web-devsecops"
  }
}

output "public_ip" {
  description = "Adresse IP publique de l'instance EC2"
  value       = aws_instance.web.public_ip
}