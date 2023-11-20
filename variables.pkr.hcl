variable "server_private_key" {
  type      = string
  sensitive = true
}

variable "server_public_key" {
  type      = string
  sensitive = true
}

variable "client_public_key" {
  type      = string
  sensitive = true
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}