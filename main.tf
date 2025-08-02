provider "aws" {
  region = var.region
}

module "ec2" {
  source         = "./ec2_instance"
   providers      = {
    aws = aws
  }
  ami_value      = "ami-0e86e20dae9224db8"
  instance_type  = "t2.micro"
  subnet         = "subnet-0bcd2a69b1fc1fead"
  instance_count = var.instance_count
  region         = var.region
}

variable "region" {

}

variable "instance_count" {
  type = number
}