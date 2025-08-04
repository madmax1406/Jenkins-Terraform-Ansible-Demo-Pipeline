variable "ami_value" {
  description = "AMI ID to launch"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "subnet" {
  description = "Subnet ID to launch into"
  type        = string
}

variable "region"       { type = string }
variable "instance_count" { type = number }
variable "key_name"     { type = string }
variable "vpc_id"       { type = string }
