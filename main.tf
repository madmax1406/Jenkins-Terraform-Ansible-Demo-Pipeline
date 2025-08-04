provider "aws" {
  region = var.region
}

module "ec2" {
  region         = var.region
  source         = "./ec2_instance"
  ami_value      = var.ami_value
  instance_type  = var.instance_type
  subnet         = var.subnet
  key_name       = var.key_name
  vpc_id         = var.vpc_id
  instance_count = var.instance_count
}