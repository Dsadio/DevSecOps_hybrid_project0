# ─── Source : https://developer.hashicorp.com/terraform/language/values/variables ───
variable "region" {
  description = "Région AWS de déploiement"
  type        = string
  default     = "eu-west-3"
}

# ─── Source : https://developer.hashicorp.com/terraform/language/values/variables#sensitive-variables ───
variable "my_ip" {
  description = "Adresse IP publique autorisée pour SSH (format CIDR)"
  type        = string
  sensitive   = true
}

# ─── Source : https://developer.hashicorp.com/terraform/language/values/variables ───
variable "key_name" {
  description = "Nom de la paire de clés SSH préexistante dans AWS"
  type        = string
  sensitive   = true
}
