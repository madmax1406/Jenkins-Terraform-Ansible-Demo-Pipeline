
resource "aws_instance" "demopsec2" {
  ami= var.ami_value
  instance_type = var.instance_type
  subnet_id = var.subnet
  count = var.instance_count
}

