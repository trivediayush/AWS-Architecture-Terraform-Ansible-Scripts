output "instance_id" { value = aws_instance.staging.id }
output "private_ip" { value = aws_instance.staging.private_ip }
output "public_ip" { value = aws_instance.staging.public_ip }
