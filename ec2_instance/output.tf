output "public_ip_for_ec2" {
  value = [for instance in aws_instance.demopsec2 : instance.public_ip if instance.public_ip != null]
}