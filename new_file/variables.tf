variable "s3_bucket_name" {
  description = "Nome do bucket S3 para armazenar o estado do Terraform"
  type        = string
}

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
