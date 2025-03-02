variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"
}

variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "Raphael"
}

variable "allowed_ssh_ips" {
  description = "IPs permitidos para acesso SSH (ex: ['123.45.67.89/32'])"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}