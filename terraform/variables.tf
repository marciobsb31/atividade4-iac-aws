variable "aws_region" {
  description = "AWS region in which the VPC and Windows instance will be created."
  type        = string
  default     = "us-east-1"
}

variable "key_name" {
  description = "Name of an existing RSA EC2 key pair in aws_region."
  type        = string
}

variable "admin_cidr" {
  description = "Public IPv4 CIDR allowed to connect over RDP and WinRM HTTPS; use your IP with /32."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr))
    error_message = "admin_cidr must be a valid IPv4 CIDR, such as 203.0.113.10/32."
  }
}

variable "http_ingress_cidr" {
  description = "IPv4 CIDR allowed to access the IIS demonstration page over HTTP."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrnetmask(var.http_ingress_cidr))
    error_message = "http_ingress_cidr must be a valid IPv4 CIDR."
  }
}

variable "instance_type" {
  description = "EC2 instance type for Windows Server 2019."
  type        = string
  default     = "t3.medium"
}

variable "project_name" {
  description = "Prefix used for resource names and tags."
  type        = string
  default     = "atividade4-iac"
}
