variable "project_name" {
  type = string
}

variable "alert_email" {
  type        = string
  description = "Correo que recibe las notificaciones de las alarmas via SNS"
}
