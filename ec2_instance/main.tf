

resource "aws_instance" "demopsec2" {
  ami                           = var.ami_value
  subnet_id                     = var.subnet
  count                         = var.instance_count
  associate_public_ip_address   = true
  vpc_security_group_ids        = [aws_security_group.web_sg.id]
  key_name                      = var.key_name
  instance_type                 = var.instance_type

  tags = {
    Name = "Demo EC2 ${count.index + 1}"
  }
}


resource "aws_security_group" "web_sg" {
  name          = "web-sg"
  description   = "Allow SSH and HTTP"
  vpc_id        = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


