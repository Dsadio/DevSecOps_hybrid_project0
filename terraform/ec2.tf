# ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance ───
# ─── Exemple : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance#example-usage ───
resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  # ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance#root_block_device ───
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  # ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance#metadata_options ───
  # ─── Source : https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-options.html ───
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 obligatoire
  }

  # ─── Source : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance#user_data ───
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y python3
              EOF

  tags = {
    Name = "web-devsecops"
  }
}
