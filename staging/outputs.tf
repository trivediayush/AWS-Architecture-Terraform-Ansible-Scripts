output "instance_id" { value = aws_instance.staging.id }
output "private_ip" { value = aws_instance.staging.private_ip }
output "public_ip" { value = aws_instance.staging.public_ip }
output "bucket_name" { value = aws_s3_bucket.staging.id }
output "bucket_arn" { value = aws_s3_bucket.staging.arn }
output "staging_log_group_name" { value = aws_cloudwatch_log_group.staging.name }
