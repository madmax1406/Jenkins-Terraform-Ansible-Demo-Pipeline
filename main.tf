provider "aws" {
  region = var.region
}

module "ec2" {
  source         = "./ec2_instance"
  ami_value      = "ami-020cba7c55df1f615"
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