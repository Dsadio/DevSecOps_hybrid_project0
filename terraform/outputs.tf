# ─── Source : https://developer.hashicorp.com/terraform/language/values/outputs ───
output "public_ip" {
  description = "Adresse IP publique de l'instance EC2"
  value       = aws_instance.web.public_ip
}

output "logs_bucket_name" {
  description = "Nom du bucket S3 pour les logs"
  value       = aws_s3_bucket.logs.bucket
}

output "security_group_id" {
  description = "ID du security group"
  value       = aws_security_group.web_sg.id
}
