variable "region" {
  description = "Région AWS de déploiement"
  type        = string
  default     = "eu-west-3"
}

variable "my_ip" {
  description = "Adresse IP publique autorisée pour SSH (format CIDR)"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])/(3[0-2]|[12]?[0-9])$", var.my_ip))
    error_message = "my_ip doit être un CIDR IPv4 valide (ex: 1.2.3.4/32)."
  }
}

variable "key_name" {
  description = "Nom de la paire de clés SSH préexistante dans AWS"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{1,64}$", var.key_name))
    error_message = "key_name : uniquement A-Za-z0-9._- (64 caractères max)."
  }
}