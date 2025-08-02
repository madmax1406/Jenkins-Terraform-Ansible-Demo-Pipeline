
resource "aws_instance" "demopsec2" {
  ami= var.ami_value
  instance_type = var.instance_type
  subnet_id = var.subnet
  count = var.instance_count
  associate_public_ip_address = true
  key_name = "jenkins-ansible-ssh-key"

  tags = {
    Name = "Demo EC2 ${count.index + 1}"
  }
}

