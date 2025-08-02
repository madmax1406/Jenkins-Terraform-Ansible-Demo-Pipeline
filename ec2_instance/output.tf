output "public_ip_for_ec2" {
  value = aws_instance.demopsec2[*].public_ip
}