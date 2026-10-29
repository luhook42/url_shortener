variable "my_ip_cidr" {
  description = "Your public IP as a /32 range; allowed to reach port 4567"
  type        = string
}

variable "alert_email" {
  description = "Email address that receives monitoring alerts"
  type        = string
}